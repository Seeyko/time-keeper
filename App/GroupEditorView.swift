import SwiftUI
import FamilyControls

struct GroupEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State var group: LimitGroup
    let isNew: Bool

    @State private var showPicker = false
    @State private var confirmDelete = false
    @State private var delayedUntil: Date?

    var body: some View {
        Form {
            Section("Nom") {
                TextField("Ex. Réseaux sociaux", text: $group.name)
            }

            Section {
                Button {
                    showPicker = true
                } label: {
                    LabeledContent("Choisir apps, catégories, sites", value: "\(group.itemCount)")
                }
                ForEach(Array(group.selection.applicationTokens), id: \.self) { token in
                    Label(token)
                }
                ForEach(Array(group.selection.categoryTokens), id: \.self) { token in
                    Label(token)
                }
                ForEach(Array(group.selection.webDomainTokens), id: \.self) { token in
                    Label(token)
                }
            } header: {
                Text("Ce qui est limité")
            } footer: {
                Text("Le temps est partagé : 30 min pour Instagram + TikTok = 30 min au total.")
            }

            Section("Temps autorisé par jour") {
                Stepper(value: $group.minutes, in: Policy.minutesRange, step: 5) {
                    Text(formatMinutes(group.minutes)).font(.title3.monospacedDigit())
                }
            }

            if !isNew {
                Section {
                    Button("Supprimer cette limite", role: .destructive) { confirmDelete = true }
                } footer: {
                    Text("La suppression ne prend effet que 24 h plus tard.")
                }
            }
        }
        .navigationTitle(isNew ? "Nouvelle limite" : group.name)
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(isPresented: $showPicker, selection: $group.selection)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") { finish(model.upsert(group)) }
                    .disabled(group.isEmpty || group.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .confirmationDialog("Supprimer cette limite ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer dans 24 h", role: .destructive) { finish(model.deleteGroup(group.id)) }
        }
        .delayedAlert($delayedUntil) { dismiss() }
    }

    private func finish(_ outcome: SaveOutcome) {
        switch outcome {
        case .immediate: dismiss()
        case .delayed(let date): delayedUntil = date
        }
    }
}
