import SwiftUI
import FamilyControls

struct AccessView: View {
    @State private var error: String?
    @State private var taps = 0

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Dial()
                .fill(Theme.accent, style: FillStyle(eoFill: true))
                .frame(width: 96, height: 96)
                .padding(.bottom, 20)
                .accessibilityHidden(true)
            Text("Time Keeper")
                .font(Theme.title)
            Text("Il a besoin de Temps d'écran pour bloquer. Rien ne quitte ton iPhone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let error {
                Text(error)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.blocked)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .safeAreaInset(edge: .bottom) {
            Button {
                taps += 1
                Task {
                    do {
                        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            } label: {
                Text("Autoriser l'accès").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .sensoryFeedback(.selection, trigger: taps)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}
