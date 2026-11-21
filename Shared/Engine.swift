import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

enum SaveOutcome: Equatable {
    /// Tout est appliqué maintenant (le changement rend plus strict, ou ne change rien).
    case immediate
    /// Une partie du changement assouplit les règles : elle s'applique à cette date.
    case delayed(until: Date)
}

/// Pose et retire les blocages.
enum Shield {
    static func apply(_ group: LimitGroup) {
        let store = ManagedSettingsStore(named: group.storeName)
        let sel = group.selection
        store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
        store.shield.applicationCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
        store.shield.webDomains = sel.webDomainTokens.isEmpty ? nil : sel.webDomainTokens
        store.shield.webDomainCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
    }

    static func clear(_ id: UUID) {
        ManagedSettingsStore(named: LimitGroup.storeName(for: id)).clearAllSettings()
    }
}

enum Engine {
    private static let domainsStore = ManagedSettingsStore.Name(rawValue: "domains")
    private static let globalStore = ManagedSettingsStore.Name(rawValue: "global")

    /// Enregistre ce que l'utilisateur a demandé.
    /// Ce qui est plus strict s'applique tout de suite, ce qui assouplit attend `Policy.loosenDelay`.
    @discardableResult
    static func save(draft: Rules, now: Date = Date()) -> SaveOutcome {
        var state = SharedStorage.load()
        state.active = Rules.strictest(state.active, draft)

        if draft == state.active {
            state.pending = nil
            state.pendingEffective = nil
        } else {
            // Le délai ne repart pas de zéro si la nouvelle demande est au moins aussi stricte que l'ancienne.
            let keepTimer = state.pending.map { draft.isAtLeastAsStrict(as: $0) } ?? false
            if !keepTimer || state.pendingEffective == nil {
                state.pendingEffective = now.addingTimeInterval(Policy.loosenDelay)
            }
            state.pending = draft
        }

        SharedStorage.save(state)
        sync(state.active)
        if let date = state.pendingEffective, state.pending != nil { return .delayed(until: date) }
        return .immediate
    }

    /// À appeler à chaque ouverture de l'app : applique les assouplissements dont le délai est passé,
    /// et remet les réglages système en phase avec les règles.
    static func applyPendingIfDue(now: Date = Date()) {
        var state = SharedStorage.load()
        if let pending = state.pending, let date = state.pendingEffective, date <= now {
            state.active = pending
            state.pending = nil
            state.pendingEffective = nil
            SharedStorage.save(state)
        }
        sync(state.active)
    }

    /// Aligne DeviceActivity et ManagedSettings sur les règles actives.
    static func sync(_ rules: Rules) {
        let center = DeviceActivityCenter()

        // 1. Limites supprimées : arrêter le suivi et lever leur blocage.
        let currentIDs = Set(rules.groups.map(\.id))
        let monitored = Set(rules.groups.filter { !$0.isEmpty }.map(\.activityName))
        for activity in center.activities where LimitGroup.id(from: activity) != nil && !monitored.contains(activity) {
            center.stopMonitoring([activity])
        }
        for id in SharedStorage.knownGroupIDs where !currentIDs.contains(id) {
            Shield.clear(id)
            SharedStorage.forget(id)
        }
        SharedStorage.knownGroupIDs = currentIDs

        // 2. Limites actives.
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
        for group in rules.groups {
            // Déjà bloqué aujourd'hui : on garde le blocage (avec la sélection à jour) jusqu'à minuit.
            if SharedStorage.isShieldedToday(group.id) { Shield.apply(group) }

            guard !group.isEmpty else {
                SharedStorage.setFingerprint(nil, for: group.id)
                continue
            }
            let fp = fingerprint(group)
            if center.activities.contains(group.activityName), SharedStorage.fingerprint(group.id) == fp {
                continue
            }
            let event = DeviceActivityEvent(
                applications: group.selection.applicationTokens,
                categories: group.selection.categoryTokens,
                webDomains: group.selection.webDomainTokens,
                threshold: DateComponents(minute: group.minutes),
                // Compte le temps déjà passé aujourd'hui : modifier une limite ne remet pas le compteur à zéro.
                includesPastActivity: true
            )
            center.stopMonitoring([group.activityName])
            do {
                try center.startMonitoring(group.activityName, during: schedule, events: [LimitGroup.eventName: event])
                SharedStorage.setFingerprint(fp, for: group.id)
            } catch {
                NSLog("TimeKeeper: startMonitoring a échoué pour \(group.name): \(error)")
            }
        }

        // 3. Sites bloqués en permanence, dans tous les navigateurs.
        let domains = ManagedSettingsStore(named: domainsStore)
        let filtered = filteredDomains(rules.blockedDomains)
        domains.webContent.blockedByFilter = filtered.isEmpty ? nil : .specific(filtered)

        // 4. Verrou anti-suppression.
        ManagedSettingsStore(named: globalStore).application.denyAppRemoval = rules.denyAppRemoval ? true : nil
    }

    /// youtube.com -> youtube.com, www.youtube.com, m.youtube.com (dans la limite autorisée).
    static func filteredDomains(_ base: [String]) -> Set<WebDomain> {
        var names: [String] = base
        for d in base { names += ["www." + d, "m." + d] }
        var seen = Set<String>()
        let unique = names.filter { seen.insert($0).inserted }
        return Set(unique.prefix(Policy.maxFilteredDomains).map { WebDomain(domain: $0) })
    }

    private static func fingerprint(_ group: LimitGroup) -> String {
        let data = (try? JSONEncoder().encode(group.selection)) ?? Data()
        return "\(group.minutes)|\(data.base64EncodedString())"
    }
}
