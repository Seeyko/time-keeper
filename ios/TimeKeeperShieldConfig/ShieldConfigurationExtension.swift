import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let night = UIColor(red: 0.043, green: 0.082, blue: 0.188, alpha: 1)

    private func mark() -> UIImage {
        let side: CGFloat = 96
        let radius = side / 2
        let inner = radius * 0.86
        let center = CGPoint(x: radius, y: radius)
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            let path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: side, height: side))
            path.append(UIBezierPath(ovalIn: CGRect(x: radius - inner, y: radius - inner, width: inner * 2, height: inner * 2)))
            let wedge = UIBezierPath()
            wedge.move(to: center)
            wedge.addArc(withCenter: center, radius: radius * 0.7, startAngle: -.pi / 2, endAngle: .pi / 6, clockwise: true)
            wedge.close()
            path.append(wedge)
            path.usesEvenOddFillRule = true
            UIColor.white.setFill()
            path.fill()
        }
    }

    private func make(title: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: night,
            icon: mark(),
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
