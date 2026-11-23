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
    static var accentGround: Color { dynamic(light: 0xEEF2FC, dark: 0x172447) }
    static var hairline: Color { dynamic(light: 0xE4E6EB, dark: 0x2C2E35) }
    static var ground: Color { dynamic(light: 0xF6EFE5, dark: 0x0E0F13) }
    static var paper: Color { dynamic(light: 0xF7EBDB, dark: 0xF7EBDB) }
    static var bark: Color { dynamic(light: 0x5B3A26, dark: 0x8A6248) }
    static var ochre: Color { dynamic(light: 0xC27E1C, dark: 0xD9952E) }
    static var slate: Color { dynamic(light: 0x5C6B8A, dark: 0x6F7FA3) }
    static var blush: Color { dynamic(light: 0xD0705F, dark: 0xD9776A) }
    static var night: Color { dynamic(light: 0x0B1530, dark: 0x0B1530) }
    static var nightSecondary: Color { dynamic(light: 0xC4CBDA, dark: 0xC4CBDA) }

    static var title: Font { .system(.largeTitle, design: .serif, weight: .semibold) }
    static var heading: Font { .system(.title, design: .serif, weight: .semibold) }
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

struct Tile: View {
    let symbol: String
    let tint: Color
    @ScaledMetric(relativeTo: .body) private var size = 29

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct TileLabel: View {
    let title: String
    let symbol: String
    let tint: Color

    init(_ title: String, symbol: String, tint: Color) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Tile(symbol: symbol, tint: tint)
        }
    }
}

extension View {
    func groupedScreen() -> some View {
        listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
    }
}
