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
                                Text("Effectif le \(date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "clock.badge.exclamationmark")
                        }
                        Button("Annuler l'assouplissement") { model.cancelPending() }
                            .sensoryFeedback(.impact, trigger: model.state.pending == nil)
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
                    Text("Limites par jour")
                } footer: {
                    Text("Temps écoulé : bloqué jusqu'à \(model.active.dayStart.label).")
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
                    Text("Dans Safari, Chrome et les autres navigateurs.")
                }

                Section {
                    DatePicker("Nouvelle journée à", selection: dayStartBinding, displayedComponents: .hourAndMinute)
                    Toggle("Empêcher la suppression d'apps", isOn: Binding(
                        get: { model.draft.denyAppRemoval },
                        set: { on in handle(model.setDenyAppRemoval(on)) }
                    ))
                } header: {
                    Text("Réglages")
                } footer: {
                    Text("Plus strict : tout de suite. Plus souple : 24 h plus tard.")
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

    private var dayStartBinding: Binding<Date> {
        Binding(
            get: {
                let d = model.draft.dayStart
                return Calendar.current.date(bySettingHour: d.hour, minute: d.minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                let wanted = DayStart(hour: c.hour ?? 0, minute: c.minute ?? 0)
                if wanted != model.draft.dayStart { handle(model.setDayStart(wanted)) }
            }
        )
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
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            if pending {
                Text("Modification dans 24 h").font(.caption).foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let time = "\(formatMinutes(group.minutes)) par jour"
        return group.isEmpty ? time : "\(time) · \(group.itemCount) élément\(group.itemCount > 1 ? "s" : "")"
    }
}

func formatMinutes(_ minutes: Int) -> String {
    let h = minutes / 60, m = minutes % 60
    if h == 0 { return "\(m) min" }
    return m == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", m))"
}

extension View {
    func delayedAlert(_ date: Binding<Date?>, onDismiss: @escaping () -> Void = {}) -> some View {
        alert("Dans 24 h", isPresented: Binding(
            get: { date.wrappedValue != nil },
            set: { if !$0 { date.wrappedValue = nil; onDismiss() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Ce qui assouplit tes règles s'appliquera le \(date.wrappedValue?.formatted(date: .abbreviated, time: .shortened) ?? "").")
        }
    }
}
