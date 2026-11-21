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
                HStack {
                    TextField("youtube.com", text: $input)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit(add)
                    Button("Ajouter", action: add)
                        .disabled(input.isEmpty)
                }
                if invalid {
                    Text("Ce n'est pas un site.").font(.footnote).foregroundStyle(.red)
                }
            } footer: {
                Text("Bloque aussi www. et m. L'app, elle, se met dans une limite.")
            }

            let missing = suggestions.filter { !model.draft.blockedDomains.contains($0) }
            if !missing.isEmpty {
                Section("Suggestions") {
                    ForEach(missing, id: \.self) { domain in
                        Button {
                            handle(model.addDomain(domain))
                        } label: {
                            Label(domain, systemImage: "plus.circle")
                        }
                    }
                }
            }

            Section("Bloqués") {
                if model.draft.blockedDomains.isEmpty {
                    Text("Aucun site").foregroundStyle(.secondary)
                }
                ForEach(model.draft.blockedDomains, id: \.self) { domain in
                    Text(domain)
                }
                .onDelete { offsets in
                    let domains = offsets.map { model.draft.blockedDomains[$0] }
                    for domain in domains { handle(model.removeDomain(domain)) }
                }
                ForEach(model.active.blockedDomains.filter { model.isDomainPendingRemoval($0) }, id: \.self) { domain in
                    HStack {
                        Text(domain).strikethrough()
                        Spacer()
                        Text("débloqué dans 24 h").font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        }
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
