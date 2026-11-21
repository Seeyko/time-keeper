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
        SharedStorage.markShieldedToday(id)
        Shield.apply(group)
    }
}
