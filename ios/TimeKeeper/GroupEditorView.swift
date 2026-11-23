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
        List {
            Section {
                Stepper(value: $group.minutes, in: Policy.minutesRange, step: 5) {
                    LabeledContent("Par jour") {
                        Text(formatMinutes(group.minutes)).monospacedDigit()
                    }
                }
                .sensoryFeedback(.selection, trigger: group.minutes)
            } header: {
                Text("Temps total par jour")
            }

            Section {
                TextField("Réseaux sociaux", text: $group.name)
            } header: {
                Text("Nom")
            }

            Section {
                Button {
                    showPicker = true
                } label: {
                    LabeledContent("Choisir", value: "\(group.itemCount)")
                }
                .sensoryFeedback(.selection, trigger: showPicker)
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
                Text("Apps et sites")
            } footer: {
                Text("Un site manque ? Ouvre-le une fois dans Safari.")
            }

            if !isNew {
                Section {
                    Button("Supprimer cette limite", role: .destructive) { confirmDelete = true }
                        .sensoryFeedback(.warning, trigger: confirmDelete) { _, shown in shown }
                }
            }
        }
        .groupedScreen()
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
