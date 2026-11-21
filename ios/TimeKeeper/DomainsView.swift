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
                Text("Dans tous les navigateurs. L'app se met dans une limite.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
                HStack(spacing: 8) {
                    TextField("youtube.com", text: $input)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit(add)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 50)
                        .background(Theme.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Button("Ajouter", action: add)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(input.isEmpty)
                }
                .listRowSeparator(.hidden)
                if invalid {
                    Text("Ce n'est pas un site.")
                        .font(.footnote)
                        .foregroundStyle(Theme.blocked)
                        .listRowSeparator(.hidden)
                }
            }

            Section {
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
                        Text(domain).strikethrough().foregroundStyle(.secondary)
                        Spacer()
                        Text("débloqué dans 24 h")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.pending)
                    }
                }
            } header: {
                SectionTitle("Bloqués")
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
                    SectionTitle("Suggestions")
                }
            }
        }
        .listStyle(.plain)
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
