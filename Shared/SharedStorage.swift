import Foundation

/// Stockage dans l'App Group, lisible par l'app et l'extension de monitoring.
enum SharedStorage {
    static let groupID: String = (Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String) ?? ""

    static var defaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }

    private static let stateKey = "state.v1"
    private static let knownGroupsKey = "knownGroups.v1"

    static func load() -> TimeKeeperState {
        guard let data = defaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(TimeKeeperState.self, from: data) else {
            return TimeKeeperState()
        }
        return state
    }

    static func save(_ state: TimeKeeperState) {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: stateKey)
        }
    }

    // MARK: - Jour courant (le blocage tient jusqu'à minuit)

    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func markShieldedToday(_ id: UUID) {
        defaults.set(dayKey(), forKey: "shieldDay." + id.uuidString)
    }

    static func isShieldedToday(_ id: UUID) -> Bool {
        defaults.string(forKey: "shieldDay." + id.uuidString) == dayKey()
    }

    // MARK: - Empreinte de la config surveillée (évite de relancer le suivi inutilement)

    static func fingerprint(_ id: UUID) -> String? {
        defaults.string(forKey: "fingerprint." + id.uuidString)
    }

    static func setFingerprint(_ value: String?, for id: UUID) {
        defaults.set(value, forKey: "fingerprint." + id.uuidString)
    }

    // MARK: - Groupes connus (pour nettoyer les blocages des limites supprimées)

    static var knownGroupIDs: Set<UUID> {
        get { Set((defaults.stringArray(forKey: knownGroupsKey) ?? []).compactMap(UUID.init(uuidString:))) }
        set { defaults.set(newValue.map(\.uuidString), forKey: knownGroupsKey) }
    }

    static func forget(_ id: UUID) {
        defaults.removeObject(forKey: "shieldDay." + id.uuidString)
        defaults.removeObject(forKey: "fingerprint." + id.uuidString)
    }
}
