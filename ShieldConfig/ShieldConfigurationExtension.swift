import ManagedSettings
import ManagedSettingsUI
import UIKit

/// L'écran de blocage : pas de "Ignorer la limite", pas de "Encore 15 minutes". Juste "Fermer".
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private func make(title: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: UIImage(systemName: "hourglass"),
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "Ta limite du jour est atteinte. Ça se débloque à minuit, pas avant.",
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
