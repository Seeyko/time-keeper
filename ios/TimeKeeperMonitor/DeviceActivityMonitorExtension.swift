import DeviceActivity
import ManagedSettings
import Foundation

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        Engine.closePassIfDue()
        guard let id = LimitGroup.id(from: activity) else { return }
        if !SharedStorage.isShieldedToday(id) {
            Shield.clear(id)
            if SharedStorage.activePass?.groupID == id {
                PassReminder.cancel()
                Engine.closePass(of: id)
            }
        }
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        closePass(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        closePass(for: activity)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if closePass(for: activity) { return }
        guard !SharedStorage.suspended,
              let id = LimitGroup.id(from: activity),
              let group = SharedStorage.load().active.groups.first(where: { $0.id == id }) else { return }
        if let reminder = Reminder(rawValue: event.rawValue) {
            let settings = SharedStorage.reminderSettings
            if reminder.minutesUsed(of: group.minutes, settings: settings) != nil && !SharedStorage.isShieldedToday(id) && SharedStorage.claimReminderToday(reminder.rawValue, for: id) {
                reminder.post(for: group, settings: settings)
            }
            return
        }
        SharedStorage.markShieldedToday(id)
        if SharedStorage.activePass?.groupID != id { Shield.apply(group) }
    }

    @discardableResult
    private func closePass(for activity: DeviceActivityName) -> Bool {
        guard let id = ActivePass.groupID(from: activity) else {
            Engine.closePassIfDue()
            return false
        }
        Engine.closePass(of: id)
        return true
    }
}
