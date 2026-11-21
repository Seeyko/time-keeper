import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let night = UIColor(red: 0.043, green: 0.082, blue: 0.188, alpha: 1)

    private func make(title: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: night,
            icon: UIImage(named: "owl-cadenas"),
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "Ta limite du jour est atteinte. Ça se débloque demain, pas avant.",
                color: UIColor(red: 0.769, green: 0.796, blue: 0.855, alpha: 1)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Fermer", color: night),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(title: "\(application.localizedDisplayName ?? "Cette app") est bloquée")
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(title: "\(application.localizedDisplayName ?? "Cette app") est bloquée")
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(title: "\(webDomain.domain ?? "Ce site") est bloqué")
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(title: "\(webDomain.domain ?? "Ce site") est bloqué")
    }
}
