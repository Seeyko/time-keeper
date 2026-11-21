import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

enum Policy {
    static let loosenDelay: TimeInterval = 24 * 60 * 60
    static let minutesRange = 5...600
    static let maxFilteredDomains = 50
}

struct DayStart: Codable, Equatable, Sendable {
    var hour = 0
    var minute = 0

    var secondsFromMidnight: TimeInterval { TimeInterval(hour * 3600 + minute * 60) }

    var intervalStart: DateComponents { DateComponents(hour: hour, minute: minute, second: 0) }

    var intervalEnd: DateComponents {
        let end = (hour * 3600 + minute * 60 + 24 * 3600 - 1) % (24 * 3600)
        return DateComponents(hour: end / 3600, minute: (end % 3600) / 60, second: end % 60)
    }

    func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let shifted = date.addingTimeInterval(-secondsFromMidnight)
        let c = calendar.dateComponents([.year, .month, .day], from: shifted)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func nextStart(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: date, matching: intervalStart, matchingPolicy: .nextTime) ?? date
    }

    var label: String { String(format: "%02d:%02d", hour, minute) }
}

struct LimitGroup: Codable, Identifiable {
    var id = UUID()
    var name: String
    var selection = FamilyActivitySelection()
    var minutes: Int = 30

    static var eventName: DeviceActivityEvent.Name { DeviceActivityEvent.Name(rawValue: "threshold") }
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

struct Rules: Codable, Equatable {
    var groups: [LimitGroup] = []
    var blockedDomains: [String] = []
    var denyAppRemoval = false
    var dayStart = DayStart()

    static func strictest(_ active: Rules, _ requested: Rules) -> Rules {
        var out = Rules()
        for wanted in requested.groups {
            if let current = active.groups.first(where: { $0.id == wanted.id }) {
                var merged = wanted
                merged.minutes = min(current.minutes, wanted.minutes)
                merged.selection.applicationTokens = current.selection.applicationTokens.union(wanted.selection.applicationTokens)
                merged.selection.categoryTokens = current.selection.categoryTokens.union(wanted.selection.categoryTokens)
                merged.selection.webDomainTokens = current.selection.webDomainTokens.union(wanted.selection.webDomainTokens)
                out.groups.append(merged)
            } else {
                out.groups.append(wanted)
            }
        }
        for current in active.groups where !requested.groups.contains(where: { $0.id == current.id }) {
            out.groups.append(current)
        }
        out.blockedDomains = requested.blockedDomains + active.blockedDomains.filter { !requested.blockedDomains.contains($0) }
        out.denyAppRemoval = active.denyAppRemoval || requested.denyAppRemoval
        out.dayStart = active.dayStart
        return out
    }

    var isUnrestricted: Bool {
        groups.isEmpty && blockedDomains.isEmpty && !denyAppRemoval
    }

    func isAtLeastAsStrict(as other: Rules) -> Bool {
        Rules.strictest(other, self) == self
    }

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

struct TimeKeeperState: Codable {
    var active = Rules()
    var pending: Rules?
    var pendingEffective: Date?

    var draft: Rules { pending ?? active }
}
