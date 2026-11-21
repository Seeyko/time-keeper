import Foundation
import DeviceActivity
import UserNotifications

struct ReminderSettings: Codable, Equatable {
    var atHalf = true
    var minutesBefore = 5

    static let beforeChoices = [0, 5, 10, 15, 30]

    var fingerprint: String { "\(atHalf)|\(minutesBefore)" }
}

enum Reminder: String, CaseIterable {
    case half
    case before

    var eventName: DeviceActivityEvent.Name { DeviceActivityEvent.Name(rawValue: rawValue) }

    func minutesUsed(of limit: Int, settings: ReminderSettings) -> Int? {
        switch self {
        case .half:
            return settings.atHalf && limit >= 20 ? limit / 2 : nil
        case .before:
            let used = limit - settings.minutesBefore
            guard settings.minutesBefore > 0, used >= 5 else { return nil }
            return settings.atHalf && limit >= 20 && used == limit / 2 ? nil : used
        }
    }

    func body(limit: Int, settings: ReminderSettings) -> String {
        switch self {
        case .half: "La moitié de ton temps est passée. Il te reste \(limit - limit / 2) min."
        case .before: "Plus que \(settings.minutesBefore) min. Ferme maintenant pour en garder pour plus tard."
        }
    }

    static func events(for group: LimitGroup, settings: ReminderSettings) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for reminder in allCases {
            guard let minutes = reminder.minutesUsed(of: group.minutes, settings: settings) else { continue }
            events[reminder.eventName] = group.event(after: minutes)
        }
        return events
    }

    static func requestPermission(then done: @escaping @MainActor @Sendable () -> Void = {}) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            Task { @MainActor in done() }
        }
    }

    func post(for group: LimitGroup, settings: ReminderSettings) {
        let content = UNMutableNotificationContent()
        content.title = group.name
        content.body = body(limit: group.minutes, settings: settings)
        content.sound = .default
        content.threadIdentifier = group.id.uuidString
        content.interruptionLevel = .timeSensitive
        let id = "\(rawValue).\(group.id.uuidString)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
