import Foundation
import DeviceActivity
import Security
import UserNotifications

struct PassLedger: Codable, Equatable, Sendable {
    var stock: Int
    var refillAnchor: Date
    var lastSeen: Date
    var lastUsedDay: String?
    var zoneID: String
    var previousZoneID: String?
    var zoneChangedAt: Date?

    init(now: Date, timeZone: TimeZone, stock: Int = Policy.passInitialStock) {
        self.stock = stock
        refillAnchor = now
        lastSeen = now
        zoneID = timeZone.identifier
    }
}

struct ActivePass: Codable, Equatable, Sendable {
    var groupID: UUID
    var opened: Date
    var until: Date

    static let prefix = "pass."
    static var eventName: DeviceActivityEvent.Name { DeviceActivityEvent.Name(rawValue: "pass") }

    var activityName: DeviceActivityName { DeviceActivityName(rawValue: ActivePass.prefix + groupID.uuidString) }

    static func groupID(from activity: DeviceActivityName) -> UUID? {
        let raw = activity.rawValue
        guard raw.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(raw.dropFirst(prefix.count)))
    }

    func isOver(at now: Date) -> Bool {
        now >= until || now < opened.addingTimeInterval(-Policy.passClockTolerance)
    }
}

enum PassAvailability: Equatable, Sendable {
    case available
    case open(until: Date)
    case night
    case usedToday
    case nothingBlocked
    case empty(next: Date)
    case clockMoved
    case suspended
}

enum PassError: Error, Equatable {
    case refused(PassAvailability)
    case monitoring
    case storage
}

enum Pass {
    static func refreshed(_ ledger: PassLedger, now: Date, timeZone: TimeZone) -> PassLedger {
        guard now >= ledger.lastSeen else { return ledger }
        var out = ledger
        out.lastSeen = now
        if out.zoneID != timeZone.identifier {
            let quarantined = out.zoneChangedAt.map { now.timeIntervalSince($0) < Policy.passZoneQuarantine } ?? false
            if !quarantined || out.previousZoneID == nil { out.previousZoneID = out.zoneID }
            out.zoneID = timeZone.identifier
            out.zoneChangedAt = now
        }
        while out.stock < Policy.passMaxStock, now.timeIntervalSince(out.refillAnchor) >= Policy.passRefill {
            out.stock += 1
            out.refillAnchor = out.refillAnchor.addingTimeInterval(Policy.passRefill)
        }
        if out.stock >= Policy.passMaxStock {
            out.stock = Policy.passMaxStock
            out.refillAnchor = now
        }
        return out
    }

    static func availability(
        _ ledger: PassLedger,
        now: Date,
        timeZone: TimeZone,
        calendar: Calendar,
        dayStart: DayStart,
        hasBlockedGroup: Bool,
        suspended: Bool,
        passActive: ActivePass?
    ) -> PassAvailability {
        if suspended { return .suspended }
        if let passActive, !passActive.isOver(at: now) { return .open(until: passActive.until) }
        if now < ledger.lastSeen.addingTimeInterval(-Policy.passClockTolerance) { return .clockMoved }
        let current = refreshed(ledger, now: now, timeZone: timeZone)
        if current.stock <= 0 { return .empty(next: current.refillAnchor.addingTimeInterval(Policy.passRefill)) }
        let calendars = zones(current, now: now, timeZone: timeZone).map { zone -> Calendar in
            var local = calendar
            local.timeZone = zone
            return local
        }
        if let used = current.lastUsedDay, calendars.contains(where: { dayStart.dayKey(for: now, calendar: $0) == used }) {
            return .usedToday
        }
        if calendars.contains(where: { isNight(now, calendar: $0) }) { return .night }
        if !hasBlockedGroup { return .nothingBlocked }
        return .available
    }

    static func spend(_ ledger: PassLedger, now: Date, timeZone: TimeZone, calendar: Calendar, dayStart: DayStart) -> PassLedger {
        var out = refreshed(ledger, now: now, timeZone: timeZone)
        guard out.stock > 0 else { return out }
        if out.stock >= Policy.passMaxStock { out.refillAnchor = now }
        out.stock -= 1
        var local = calendar
        local.timeZone = timeZone
        out.lastUsedDay = dayStart.dayKey(for: now, calendar: local)
        return out
    }

    static func isNight(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= Policy.passNightStartHour || hour < Policy.passNightEndHour
    }

    private static func zones(_ ledger: PassLedger, now: Date, timeZone: TimeZone) -> [TimeZone] {
        var ids: [String] = []
        if ledger.zoneID != timeZone.identifier { ids.append(ledger.zoneID) }
        if let previous = ledger.previousZoneID, let changed = ledger.zoneChangedAt,
           now.timeIntervalSince(changed) < Policy.passZoneQuarantine {
            ids.append(previous)
        }
        return [timeZone] + ids.compactMap { TimeZone(identifier: $0) }
    }
}

enum PassStore {
    private static let account = "pass.ledger.v1"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.seeyko.timekeeper",
            kSecAttrAccount as String: account,
        ]
    }

    static func load(now: Date = Date(), timeZone: TimeZone = .current) -> PassLedger? {
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(search as CFDictionary, &item)
        if status == errSecItemNotFound { return PassLedger(now: now, timeZone: timeZone) }
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return (try? JSONDecoder().decode(PassLedger.self, from: data)) ?? PassLedger(now: now, timeZone: timeZone)
    }

    @discardableResult
    static func save(_ ledger: PassLedger) -> Bool {
        guard let data = try? JSONEncoder().encode(ledger) else { return false }
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else { return status == errSecSuccess }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }
}

enum PassReminder: String, Codable, CaseIterable, Sendable {
    case minuteBefore
    case atEnd
    case never

    static let identifier = "pass"

    var notice: (lead: TimeInterval, body: String)? {
        switch self {
        case .minuteBefore: return (lead: 60, body: "Plus qu'une minute.")
        case .atEnd: return (lead: 0, body: "C'est refermé.")
        case .never: return nil
        }
    }

    func schedule(for group: LimitGroup, until: Date, now: Date = Date()) {
        PassReminder.cancel()
        guard let notice else { return }
        let delay = until.timeIntervalSince(now) - notice.lead
        guard delay > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = group.name
        content.body = notice.body
        content.sound = .default
        content.threadIdentifier = group.id.uuidString
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: PassReminder.identifier, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [PassReminder.identifier])
    }
}
