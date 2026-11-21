import Foundation
import DeviceActivity
import UserNotifications

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

    static func events(for group: LimitGroup) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for reminder in allCases {
            guard let minutes = reminder.minutesUsed(of: group.minutes) else { continue }
            events[reminder.eventName] = group.event(after: minutes)
        }
        return events
    }

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(for group: LimitGroup) {
        let content = UNMutableNotificationContent()
        content.title = group.name
        content.body = body(limit: group.minutes)
        content.sound = .default
        content.interruptionLevel = .active
        let id = "\(rawValue).\(group.id.uuidString)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
