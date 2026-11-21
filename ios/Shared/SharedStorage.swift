import Foundation

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

    static func todayKey(_ date: Date = Date()) -> String {
        load().active.dayStart.dayKey(for: date)
    }

    static func markShieldedToday(_ id: UUID) {
        defaults.set(todayKey(), forKey: "shieldDay." + id.uuidString)
    }

    static func isShieldedToday(_ id: UUID) -> Bool {
        defaults.string(forKey: "shieldDay." + id.uuidString) == todayKey()
    }

    static func fingerprint(_ id: UUID) -> String? {
        defaults.string(forKey: "fingerprint." + id.uuidString)
    }

    static func setFingerprint(_ value: String?, for id: UUID) {
        defaults.set(value, forKey: "fingerprint." + id.uuidString)
    }

    static var knownGroupIDs: Set<UUID> {
        get { Set((defaults.stringArray(forKey: knownGroupsKey) ?? []).compactMap(UUID.init(uuidString:))) }
        set { defaults.set(newValue.map(\.uuidString), forKey: knownGroupsKey) }
    }

    static func forget(_ id: UUID) {
        defaults.removeObject(forKey: "shieldDay." + id.uuidString)
        defaults.removeObject(forKey: "fingerprint." + id.uuidString)
    }
}
