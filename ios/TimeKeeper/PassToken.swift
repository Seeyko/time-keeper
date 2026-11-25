import SwiftUI
import Metal

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
    var ticking = true
    @Environment(\.colorScheme) private var scheme

    private static var threeD: Bool { device && TokenModel.prototype != nil }
    private static let device = MTLCreateSystemDefaultDevice() != nil

    private var spoken: String {
        switch face {
        case .rest: "\(stock) sur \(Policy.passMaxStock)"
        case .airlock: "Ouverture en cours"
        case .open(let left): PassToken.remaining(left)
        case .spent: "Vide"
        }
    }

    private static func remaining(_ left: Double) -> String {
        let seconds = Int((left * Policy.passDuration).rounded())
        let minutes = seconds / 60
        let rest = seconds % 60
        if minutes == 0 { return "reste \(rest) s" }
        if rest == 0 { return "reste \(minutes) min" }
        return "reste \(minutes) min \(rest) s"
    }

    var body: some View {
        Group {
            if PassToken.threeD {
                ZStack {
                    Ellipse()
                        .fill(Color.black.opacity(scheme == .dark ? 0.6 : 0.25))
                        .frame(width: size * 0.7, height: size * 0.16)
                        .blur(radius: size * 0.06)
                        .offset(y: size * 0.47)
                    TokenScene(face: face, stock: stock, ticking: ticking)
                }
            } else {
                FlatPassToken(face: face, stock: stock, size: size)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Parenthèse")
        .accessibilityValue(spoken)
    }
}
