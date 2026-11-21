import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Les règles "anti-triche".
enum Policy {
    /// Délai avant qu'un assouplissement (limite plus haute, app retirée, site débloqué,
    /// verrou désactivé, limite supprimée) prenne effet. Tout ce qui rend plus strict est immédiat.
    static let loosenDelay: TimeInterval = 24 * 60 * 60
    static let minutesRange = 5...600
    /// ManagedSettings accepte un nombre limité de domaines dans le filtre web.
    static let maxFilteredDomains = 50
}

/// Une limite quotidienne : un ensemble d'apps / catégories / sites qui partagent un même temps.
struct LimitGroup: Codable, Identifiable {
    var id = UUID()
    var name: String
    var selection = FamilyActivitySelection()
    var minutes: Int = 30

    static let eventName = DeviceActivityEvent.Name(rawValue: "threshold")
    static let prefix = "limit."

    var key: String { LimitGroup.prefix + id.uuidString }
    var activityName: DeviceActivityName { DeviceActivityName(rawValue: key) }
    var storeName: ManagedSettingsStore.Name { ManagedSettingsStore.Name(rawValue: key) }

    var itemCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }
    var isEmpty: Bool { itemCount == 0 }

    static func id(from activity: DeviceActivityName) -> UUID? {
        let raw = activity.rawValue
        guard raw.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(raw.dropFirst(prefix.count)))
    }

    static func storeName(for id: UUID) -> ManagedSettingsStore.Name {
        ManagedSettingsStore.Name(rawValue: prefix + id.uuidString)
    }
}

extension LimitGroup: Equatable {
    static func == (l: LimitGroup, r: LimitGroup) -> Bool {
        l.id == r.id && l.name == r.name && l.minutes == r.minutes
            && l.selection.applicationTokens == r.selection.applicationTokens
            && l.selection.categoryTokens == r.selection.categoryTokens
            && l.selection.webDomainTokens == r.selection.webDomainTokens
    }
}

/// L'ensemble des règles de blocage.
struct Rules: Codable, Equatable {
    var groups: [LimitGroup] = []
    /// Domaines bloqués en permanence, dans tous les navigateurs (filtre web système).
    var blockedDomains: [String] = []
    /// Empêche la suppression d'apps (dont Time Keeper) tant que c'est actif.
    var denyAppRemoval = false

    /// Combine deux jeux de règles en gardant, pour chaque point, le plus strict.
    /// L'ordre et les noms suivent `b`.
    static func strictest(_ a: Rules, _ b: Rules) -> Rules {
        var out = Rules()
        for gb in b.groups {
            if let ga = a.groups.first(where: { $0.id == gb.id }) {
                var merged = gb
                merged.minutes = min(ga.minutes, gb.minutes)
                merged.selection.applicationTokens = ga.selection.applicationTokens.union(gb.selection.applicationTokens)
                merged.selection.categoryTokens = ga.selection.categoryTokens.union(gb.selection.categoryTokens)
                merged.selection.webDomainTokens = ga.selection.webDomainTokens.union(gb.selection.webDomainTokens)
                out.groups.append(merged)
            } else {
                out.groups.append(gb)
            }
        }
        for ga in a.groups where !b.groups.contains(where: { $0.id == ga.id }) {
            out.groups.append(ga)
        }
        out.blockedDomains = b.blockedDomains + a.blockedDomains.filter { !b.blockedDomains.contains($0) }
        out.denyAppRemoval = a.denyAppRemoval || b.denyAppRemoval
        return out
    }

    /// Vrai si `self` ne relâche rien par rapport à `other`.
    func isAtLeastAsStrict(as other: Rules) -> Bool {
        Rules.strictest(other, self) == self
    }

    /// "https://www.YouTube.com/watch?v=x" -> "youtube.com". Nil si ce n'est pas un domaine.
    static func normalizeDomain(_ input: String) -> String? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let r = s.range(of: "://") { s = String(s[r.upperBound...]) }
        if let i = s.firstIndex(where: { "/?#:".contains($0) }) { s = String(s[..<i]) }
        if s.hasPrefix("www.") { s.removeFirst(4) }
        let allowed = s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }
        guard allowed, s.contains("."), !s.hasPrefix("."), !s.hasSuffix("."), !s.contains("..") else { return nil }
        return s
    }
}

/// État persistant partagé entre l'app et les extensions (App Group).
struct TimeKeeperState: Codable {
    /// Règles appliquées maintenant.
    var active = Rules()
    /// Règles plus souples demandées, appliquées à `pendingEffective`.
    var pending: Rules?
    var pendingEffective: Date?

    /// Ce que l'utilisateur voit et édite : la version future si elle existe.
    var draft: Rules { pending ?? active }
}
