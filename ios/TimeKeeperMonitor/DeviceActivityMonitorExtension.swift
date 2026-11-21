import DeviceActivity
import ManagedSettings
import Foundation

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let id = LimitGroup.id(from: activity) else { return }
        if !SharedStorage.isShieldedToday(id) {
            Shield.clear(id)
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard let id = LimitGroup.id(from: activity),
              let group = SharedStorage.load().active.groups.first(where: { $0.id == id }) else { return }
        if let reminder = Reminder(rawValue: event.rawValue) {
            let settings = SharedStorage.reminderSettings
            if reminder.minutesUsed(of: group.minutes, settings: settings) != nil && !SharedStorage.isShieldedToday(id) && SharedStorage.claimReminderToday(reminder.rawValue, for: id) {
                reminder.post(for: group, settings: settings)
            }
            return
        }
        SharedStorage.markShieldedToday(id)
        Shield.apply(group)
    }
}
