import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private func make(title: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: UIImage(systemName: "hourglass"),
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "Ta limite du jour est atteinte. Ça se débloque demain, pas avant.",
                color: .lightGray
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Fermer", color: .black),
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
