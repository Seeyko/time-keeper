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
        if let used = LiveLimit.usedMinutes(from: event) {
            if !SharedStorage.isShieldedToday(id) && SharedStorage.claimReminderToday(event.rawValue, for: id) {
                LiveLimit.send(SharedStorage.liveUpdateToken(for: id) == nil ? "start" : "update", group: group, remaining: group.minutes - used)
            }
            return
        }
        if let reminder = Reminder(rawValue: event.rawValue) {
            if SharedStorage.reminderPlan.reminders.contains(reminder) && !SharedStorage.isShieldedToday(id) && SharedStorage.claimReminderToday(reminder.rawValue, for: id) {
                reminder.post(for: group)
            }
            return
        }
        SharedStorage.markShieldedToday(id)
        Shield.apply(group)
        LiveLimit.send("end", group: group, remaining: 0)
        SharedStorage.setLiveUpdateToken(nil, for: id.uuidString)
    }
}
