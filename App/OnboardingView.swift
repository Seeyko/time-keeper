import SwiftUI
import FamilyControls

struct OnboardingView: View {
    @State private var error: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "hourglass")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Time Keeper")
                .font(.largeTitle.bold())
            Text("Pour bloquer des apps et des sites, Time Keeper a besoin de l'accès à Temps d'écran. Tout reste sur ton iPhone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
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
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            Spacer()
        }
        .padding(24)
    }
}
