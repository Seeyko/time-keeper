import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

enum SaveOutcome: Equatable {
    case immediate
    case delayed(until: Date)
}

enum Shield {
    static func apply(_ group: LimitGroup) {
        let store = ManagedSettingsStore(named: group.storeName)
        let sel = group.selection
        store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
        store.shield.applicationCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
        store.shield.webDomains = sel.webDomainTokens.isEmpty ? nil : sel.webDomainTokens
        store.shield.webDomainCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
        let sites = Engine.filteredDomains(sel.webDomains.compactMap(\.domain).compactMap(Rules.normalizeDomain))
        store.webContent.blockedByFilter = sites.isEmpty ? nil : .specific(sites)
    }

    static func clear(_ id: UUID) {
        ManagedSettingsStore(named: LimitGroup.storeName(for: id)).clearAllSettings()
    }
}

enum Engine {
    @discardableResult
    static func save(draft: Rules, now: Date = Date()) -> SaveOutcome {
        var state = SharedStorage.load()
        state = plan(state, draft: draft, now: now)
        SharedStorage.save(state)
        sync(state.active)
        if let date = state.pendingEffective, state.pending != nil { return .delayed(until: date) }
        return .immediate
    }

    static func plan(_ current: TimeKeeperState, draft: Rules, now: Date) -> TimeKeeperState {
        var state = current
        state.active = state.active.isUnrestricted && state.pending == nil ? draft : Rules.strictest(state.active, draft)
        if draft == state.active {
            state.pending = nil
            state.pendingEffective = nil
        } else {
            let keepTimer = state.pending.map { draft.isAtLeastAsStrict(as: $0) } ?? false
            if !keepTimer || state.pendingEffective == nil {
                state.pendingEffective = now.addingTimeInterval(Policy.loosenDelay)
            }
            state.pending = draft
        }
        return state
    }

    static func promote(_ current: TimeKeeperState, now: Date) -> TimeKeeperState {
        var state = current
        if let pending = state.pending, let date = state.pendingEffective, date <= now {
            state.active = pending
            state.pending = nil
            state.pendingEffective = nil
        }
        return state
    }

    static func applyPendingIfDue(now: Date = Date()) {
        let state = promote(SharedStorage.load(), now: now)
        SharedStorage.save(state)
        sync(state.active)
    }

    static func sync(_ rules: Rules) {
        let center = DeviceActivityCenter()

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

        let reminderPlan = SharedStorage.reminderPlan
        let schedule = DeviceActivitySchedule(
            intervalStart: rules.dayStart.intervalStart,
            intervalEnd: rules.dayStart.intervalEnd,
            repeats: true
        )
        for group in rules.groups {
            if SharedStorage.isShieldedToday(group.id) { Shield.apply(group) }

            guard !group.isEmpty else {
                SharedStorage.setFingerprint(nil, for: group.id)
                continue
            }
            let fp = fingerprint(group, dayStart: rules.dayStart, plan: reminderPlan)
            if center.activities.contains(group.activityName), SharedStorage.fingerprint(group.id) == fp {
                continue
            }
            var events = Reminder.events(for: group, plan: reminderPlan)
            events[LimitGroup.eventName] = group.event(after: group.minutes)
            center.stopMonitoring([group.activityName])
            do {
                try center.startMonitoring(group.activityName, during: schedule, events: events)
                SharedStorage.setFingerprint(fp, for: group.id)
            } catch {
                NSLog("TimeKeeper startMonitoring \(group.name): \(error)")
            }
        }

        let domains = ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: "domains"))
        let filtered = filteredDomains(rules.blockedDomains)
        domains.webContent.blockedByFilter = filtered.isEmpty ? nil : .specific(filtered)

        let global = ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: "global"))
        global.application.denyAppRemoval = rules.denyAppRemoval ? true : nil
    }

    static func filteredDomainNames(_ base: [String]) -> [String] {
        var names = base
        for d in base { names += ["www." + d, "m." + d] }
        var seen = Set<String>()
        return Array(names.filter { seen.insert($0).inserted }.prefix(Policy.maxFilteredDomains))
    }

    static func filteredDomains(_ base: [String]) -> Set<WebDomain> {
        Set(filteredDomainNames(base).map { WebDomain(domain: $0) })
    }

    private static func fingerprint(_ group: LimitGroup, dayStart: DayStart, plan: ReminderPlan) -> String {
        let data = (try? JSONEncoder().encode(group.selection)) ?? Data()
        return "\(plan.rawValue)|\(dayStart.label)|\(group.minutes)|\(data.base64EncodedString())"
    }
}
