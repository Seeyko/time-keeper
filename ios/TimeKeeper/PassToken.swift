import SwiftUI

struct PassToken: View {
    enum Face: Equatable {
        case rest
        case airlock(Double)
        case open(Double)
        case spent
    }

    let face: Face
    let stock: Int
    var size: CGFloat = 168
    @Environment(\.colorScheme) private var scheme

    private static let brass = Gradient(stops: [
        .init(color: Color(hex: 0xFFF3C9), location: 0),
        .init(color: Color(hex: 0xD9B25F), location: 0.10),
        .init(color: Color(hex: 0x9A7128), location: 0.22),
        .init(color: Color(hex: 0xE6C272), location: 0.34),
        .init(color: Color(hex: 0xFBE9B4), location: 0.46),
        .init(color: Color(hex: 0xB8893A), location: 0.58),
        .init(color: Color(hex: 0x7E5A1E), location: 0.70),
        .init(color: Color(hex: 0xD6AE5A), location: 0.84),
        .init(color: Color(hex: 0xFFF3C9), location: 1),
    ])

    private static let steel = Gradient(stops: [
        .init(color: Color(hex: 0x3558C0), location: 0),
        .init(color: Color(hex: 0x1F3A8A), location: 0.55),
        .init(color: Color(hex: 0x142866), location: 1),
    ])

    private static let brushing = Gradient(stops: [
        .init(color: .white.opacity(0.22), location: 0),
        .init(color: .black.opacity(0.25), location: 0.14),
        .init(color: .white.opacity(0.12), location: 0.30),
        .init(color: .black.opacity(0.30), location: 0.50),
        .init(color: .white.opacity(0.20), location: 0.66),
        .init(color: .black.opacity(0.22), location: 0.84),
        .init(color: .white.opacity(0.22), location: 1),
    ])

    private static let gold = LinearGradient(
        colors: [Color(hex: 0xFFF1C4), Color(hex: 0xC99A45)],
        startPoint: .top,
        endPoint: .bottom
    )

    private var spread: Double {
        switch face {
        case .rest, .spent: 0
        case .airlock(let progress): 0.7 * progress
        case .open: 1
        }
    }

    private var arc: Double {
        switch face {
        case .rest, .spent: 0
        case .airlock(let progress): progress
        case .open(let left): left
        }
    }

    private var spoken: String {
        switch face {
        case .rest: "\(stock) sur \(Policy.passMaxStock)"
        case .airlock: "Ouverture en cours"
        case .open: "Ouverte"
        case .spent: "Vide"
        }
    }

    private var hairline: CGFloat { max(1, size / 200) }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(scheme == .dark ? 0.55 : 0.22))
                .padding(size * 0.04)
                .blur(radius: size * 0.045)
                .offset(y: size * 0.05)
            metal
                .compositingGroup()
                .grayscale(face == .spent ? 1 : 0)
                .opacity(face == .spent ? 0.62 : 1)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Parenthèse")
        .accessibilityValue(spoken)
    }

    private var metal: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(gradient: PassToken.brass, center: .center))
            dial
            ForEach(0..<Policy.passMaxStock, id: \.self) { index in
                jewel(lit: stock > index)
                    .offset(y: -size * 0.47)
                    .rotationEffect(.degrees(Double(index) * 26 - 13))
            }
        }
    }

    private var dial: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    gradient: PassToken.steel,
                    center: UnitPoint(x: 0.4, y: 0.3),
                    startRadius: 0,
                    endRadius: size * 0.66
                ))
            Circle()
                .fill(AngularGradient(gradient: PassToken.brushing, center: .center))
            Circle()
                .strokeBorder(Color(hex: 0x0A1030).opacity(0.6), lineWidth: hairline)
            Guilloche()
                .stroke(Color.white.opacity(0.13), lineWidth: hairline)
                .frame(width: size * 0.8, height: size * 0.8)
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: size * 0.02)
                .frame(width: size * 0.81, height: size * 0.81)
            Circle()
                .trim(from: 0, to: arc)
                .stroke(Color(hex: 0xF6E3A8), style: StrokeStyle(lineWidth: size * 0.02, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size * 0.81, height: size * 0.81)
                .opacity(arc > 0 ? 1 : 0)
            Circle()
                .fill(Color(hex: 0x16296B))
                .frame(width: size * 0.45, height: size * 0.45)
            Circle()
                .strokeBorder(PassToken.gold, lineWidth: hairline)
                .frame(width: size * 0.45, height: size * 0.45)
            Parentheses(spread: spread)
                .stroke(PassToken.gold, style: StrokeStyle(lineWidth: size * 0.032, lineCap: .round))
                .frame(width: size * 0.45, height: size * 0.45)
            Circle()
                .trim(from: 0.56, to: 0.72)
                .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: size * 0.014, lineCap: .round))
                .frame(width: size * 0.68, height: size * 0.68)
            Circle()
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.2), Color.white.opacity(0)],
                    startPoint: .topLeading,
                    endPoint: .center
                ))
        }
        .frame(width: size * 0.88, height: size * 0.88)
    }

    private func jewel(lit: Bool) -> some View {
        Circle()
            .fill(Color(hex: 0x2B1D05).opacity(0.8))
            .frame(width: size * 0.05, height: size * 0.05)
            .overlay {
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.032, height: size * 0.032)
                    .opacity(lit ? 1 : 0)
            }
    }
}

struct Parentheses: Shape {
    var spread: Double

    var animatableData: Double {
        get { spread }
        set { spread = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let unit = rect.width / 0.45
        let half = unit * 0.115
        let sag = unit * 0.055
        let apex = unit * CGFloat(0.075 + 0.095 * spread)
        var path = Path()
        for side: CGFloat in [-1, 1] {
            let x = rect.midX + side * (apex - sag)
            path.move(to: CGPoint(x: x, y: rect.midY - half))
            path.addQuadCurve(
                to: CGPoint(x: x, y: rect.midY + half),
                control: CGPoint(x: x + side * 2 * sag, y: rect.midY)
            )
        }
        return path
    }
}

struct Guilloche: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 4
        var path = Path()
        for step in 0..<24 {
            let angle = CGFloat(step) / 24 * 2 * .pi
            let center = CGPoint(x: rect.midX + radius * cos(angle), y: rect.midY + radius * sin(angle))
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
