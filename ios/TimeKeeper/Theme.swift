import SwiftUI
import UIKit

enum Theme {
    static var accent: Color { dynamic(light: 0x1F3A8A, dark: 0x9DB7FF) }
    static var toggle: Color { dynamic(light: 0x1F3A8A, dark: 0x3F63D8) }
    static var onAccent: Color { dynamic(light: 0xFFFFFF, dark: 0x0B1530) }
    static var blocked: Color { dynamic(light: 0xB3261E, dark: 0xFF8A80) }
    static var pending: Color { dynamic(light: 0x8A5300, dark: 0xFFB84D) }
    static var pendingGround: Color { dynamic(light: 0xFFF4DE, dark: 0x2A1F0A) }
    static var field: Color { dynamic(light: 0xF0F1F4, dark: 0x1C1D22) }

    static var title: Font { .system(.largeTitle, design: .serif, weight: .semibold) }
    static var section: Font { .system(.title2, design: .serif, weight: .semibold) }
    static var value: Font { .system(.title2, design: .serif).monospacedDigit() }

    @MainActor
    static func applyNavigationTitle() {
        let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
        guard let serif = base.withDesign(.serif)?.withSymbolicTraits(.traitBold) else { return }
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFont(descriptor: serif, size: 0)]
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

struct Dial: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let inner = radius * 0.86
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        path.addEllipse(in: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2))
        path.move(to: center)
        path.addArc(center: center, radius: radius * 0.7, startAngle: .degrees(-90), endAngle: .degrees(30), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 18)
            .frame(minHeight: 50)
            .foregroundStyle(Theme.onAccent)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

struct SectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(Theme.section)
            .foregroundStyle(.primary)
            .textCase(nil)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .systemBackground).padding(.horizontal, -40).padding(.vertical, -8))
            .accessibilityAddTraits(.isHeader)
    }
}
