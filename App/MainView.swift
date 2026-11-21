import SwiftUI
import FamilyControls

struct MainView: View {
    @EnvironmentObject private var model: AppModel
    @State private var delayedUntil: Date?
    @State private var newGroup: LimitGroup?

    var body: some View {
        NavigationStack {
            List {
                if let date = model.state.pendingEffective, model.state.pending != nil {
                    Section {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Assouplissement en attente").font(.headline)
                                Text("Prend effet \(date.formatted(date: .abbreviated, time: .shortened)).")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "clock.badge.exclamationmark")
                        }
                        Button("Annuler l'assouplissement") { model.cancelPending() }
                    }
                }

                Section {
                    ForEach(model.draft.groups) { group in
                        NavigationLink {
                            GroupEditorView(group: group, isNew: false)
                        } label: {
                            GroupRow(group: group,
                                     blocked: model.isBlockedToday(group.id),
                                     pending: model.hasPendingChange(group.id))
                        }
                    }
                    Button {
                        newGroup = LimitGroup(name: "")
                    } label: {
                        Label("Ajouter une limite", systemImage: "plus")
                    }
                } header: {
                    Text("Limites quotidiennes")
                } footer: {
                    Text("Quand le temps est écoulé, les apps et sites choisis sont bloqués jusqu'à minuit. Aucun bouton pour rallonger.")
                }

                Section {
                    NavigationLink {
                        DomainsView()
                    } label: {
                        LabeledContent("Sites bloqués", value: "\(model.draft.blockedDomains.count)")
                    }
                } header: {
                    Text("Toujours bloqués")
                } footer: {
                    Text("Bloqués dans Safari, Chrome et les autres navigateurs, sans bloquer le navigateur lui-même.")
                }

                Section {
                    Toggle("Empêcher la suppression d'apps", isOn: Binding(
                        get: { model.draft.denyAppRemoval },
                        set: { on in handle(model.setDenyAppRemoval(on)) }
                    ))
                } header: {
                    Text("Verrouillage")
                } footer: {
                    Text("Empêche de supprimer Time Keeper (et les autres apps) pour contourner les limites.")
                }

                Section {
                    Text("Tout ce qui rend plus strict s'applique tout de suite. Tout ce qui assouplit (limite plus longue, app retirée, site débloqué, verrou coupé) ne s'applique que 24 h plus tard.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Règle du jeu")
                }
            }
            .navigationTitle("Time Keeper")
            .sheet(item: $newGroup) { group in
                NavigationStack {
                    GroupEditorView(group: group, isNew: true)
                }
            }
            .delayedAlert($delayedUntil)
        }
    }

    private func handle(_ outcome: SaveOutcome) {
        if case .delayed(let date) = outcome { delayedUntil = date }
    }
}

private struct GroupRow: View {
    let group: LimitGroup
    let blocked: Bool
    let pending: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(group.name.isEmpty ? "Sans nom" : group.name).font(.headline)
                Spacer()
                if blocked {
                    Text("Bloqué").font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(.red.opacity(0.15), in: Capsule())
                        .foregroundStyle(.red)
                }
            }
            Text("\(formatMinutes(group.minutes)) par jour · \(group.itemCount) élément(s)")
                .font(.subheadline).foregroundStyle(.secondary)
            if pending {
                Text("Modification en attente").font(.caption).foregroundStyle(.orange)
            }
        }
    }
}

func formatMinutes(_ minutes: Int) -> String {
    let h = minutes / 60, m = minutes % 60
    if h == 0 { return "\(m) min" }
    return m == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", m))"
}

extension View {
    /// Explique qu'un changement qui assouplit ne s'applique pas tout de suite.
    func delayedAlert(_ date: Binding<Date?>, onDismiss: @escaping () -> Void = {}) -> some View {
        alert("Changement programmé", isPresented: Binding(
            get: { date.wrappedValue != nil },
            set: { if !$0 { date.wrappedValue = nil; onDismiss() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Pour rester strict, la partie qui assouplit tes règles s'appliquera le \(date.wrappedValue?.formatted(date: .abbreviated, time: .shortened) ?? "").")
        }
    }
}
