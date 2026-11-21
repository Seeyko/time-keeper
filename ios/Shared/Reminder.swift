import Foundation
import DeviceActivity
import UserNotifications

enum ReminderPlan: String, CaseIterable, Identifiable {
    case halfAndLastFive
    case lastFive
    case off

    var id: String { rawValue }

    var reminders: [Reminder] {
        switch self {
        case .halfAndLastFive: [.half, .lastFive]
        case .lastFive: [.lastFive]
        case .off: []
        }
    }

    var label: String {
        switch self {
        case .halfAndLastFive: "À la moitié et 5 min avant"
        case .lastFive: "5 min avant"
        case .off: "Jamais"
        }
    }
}

enum Reminder: String, CaseIterable {
    case half
    case lastFive

    var eventName: DeviceActivityEvent.Name { DeviceActivityEvent.Name(rawValue: rawValue) }

    func minutesUsed(of limit: Int) -> Int? {
        switch self {
        case .half: limit >= 20 ? limit / 2 : nil
        case .lastFive: limit >= 10 ? limit - 5 : nil
        }
    }

    func body(limit: Int) -> String {
        switch self {
        case .half: "La moitié de ton temps est passée. Il te reste \(limit - limit / 2) min."
        case .lastFive: "Plus que 5 min. Ferme maintenant pour en garder pour plus tard."
        }
    }

    static func events(for group: LimitGroup, plan: ReminderPlan) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for reminder in plan.reminders {
            guard let minutes = reminder.minutesUsed(of: group.minutes) else { continue }
            events[reminder.eventName] = group.event(after: minutes)
        }
        return events
    }

    static func requestPermission(then done: @escaping @MainActor @Sendable () -> Void = {}) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            Task { @MainActor in done() }
        }
    }

    func post(for group: LimitGroup) {
        let content = UNMutableNotificationContent()
        content.title = group.name
        content.body = body(limit: group.minutes)
        content.sound = .default
        content.threadIdentifier = group.id.uuidString
        content.interruptionLevel = .timeSensitive
        let id = "\(rawValue).\(group.id.uuidString)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
