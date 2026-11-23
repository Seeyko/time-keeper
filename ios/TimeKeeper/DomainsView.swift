import SwiftUI

struct DomainsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var input = ""
    @State private var invalid = false
    @State private var delayedUntil: Date?

    private let suggestions = ["youtube.com", "instagram.com", "tiktok.com", "x.com", "facebook.com", "reddit.com"]

    var body: some View {
        List {
            Section {
                TextField("youtube.com", text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .onSubmit(add)
                Button("Bloquer ce site", action: add)
                    .disabled(input.isEmpty)
            } footer: {
                if invalid {
                    Text("Écris-le comme ça : youtube.com")
                        .foregroundStyle(Theme.blocked)
                } else {
                    Text("Tout le temps, dans tous les navigateurs. Pour l'app, crée une limite.")
                }
            }

            Section {
                ForEach(model.draft.blockedDomains, id: \.self) { domain in
                    Text(domain)
                }
                .onDelete { offsets in
                    let domains = offsets.map { model.draft.blockedDomains[$0] }
                    for domain in domains { handle(model.removeDomain(domain)) }
                }
                ForEach(model.active.blockedDomains.filter { model.isDomainPendingRemoval($0) }, id: \.self) { domain in
                    HStack {
                        Text(domain).strikethrough().foregroundStyle(.secondary)
                        Spacer()
                        Text("débloqué le \(model.state.pendingEffective?.formatted(date: .abbreviated, time: .shortened) ?? "")")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.pending)
                    }
                }
            }

            let missing = suggestions.filter { !model.draft.blockedDomains.contains($0) }
            if !missing.isEmpty {
                Section {
                    ForEach(missing, id: \.self) { domain in
                        Button {
                            handle(model.addDomain(domain))
                        } label: {
                            Label(domain, systemImage: "plus")
                        }
                    }
                } header: {
                    Text("Suggestions")
                }
            }
        }
        .groupedScreen()
        .navigationTitle("Sites bloqués")
        .delayedAlert($delayedUntil)
    }

    private func add() {
        guard let domain = Rules.normalizeDomain(input) else {
            invalid = true
            return
        }
        invalid = false
        input = ""
        handle(model.addDomain(domain))
    }

    private func handle(_ outcome: SaveOutcome) {
        if case .delayed(let date) = outcome { delayedUntil = date }
    }
}
