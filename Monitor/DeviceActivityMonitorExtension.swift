import DeviceActivity
import ManagedSettings
import Foundation

/// Appelée par iOS en arrière-plan, même si l'app est fermée.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    /// Début de journée (minuit), ou relance du suivi après une modification.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let id = LimitGroup.id(from: activity) else { return }
        // On ne lève le blocage que s'il date d'un jour précédent :
        // relancer le suivi en cours de journée ne débloque rien.
        if !SharedStorage.isShieldedToday(id) {
            Shield.clear(id)
        }
    }

    /// Limite du jour atteinte : on bloque jusqu'à minuit.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard let id = LimitGroup.id(from: activity),
              let group = SharedStorage.load().active.groups.first(where: { $0.id == id }) else { return }
        SharedStorage.markShieldedToday(id)
        Shield.apply(group)
    }
}
