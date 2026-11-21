import SwiftUI
import FamilyControls

struct MainView: View {
    @EnvironmentObject private var model: AppModel
    @State private var delayedUntil: Date?
    @State private var newGroup: LimitGroup?

    private var pendingIcon: some View {
        Image(systemName: "clock")
            .font(.title3)
            .foregroundStyle(Theme.pending)
            .accessibilityHidden(true)
    }

    private func pendingText(_ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Assouplissement en attente").font(.headline)
            Text("Effectif le \(date.formatted(date: .abbreviated, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(Theme.pending)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var cancelPendingButton: some View {
        Button("Annuler") { model.cancelPending() }
            .buttonStyle(.borderless)
            .font(.callout.weight(.semibold))
            .foregroundStyle(Theme.pending)
            .frame(minHeight: 44)
            .accessibilityLabel("Annuler l'assouplissement")
    }

    var body: some View {
        NavigationStack {
            List {
                if let date = model.state.pendingEffective, model.state.pending != nil {
                    Section {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) {
                                pendingIcon
                                pendingText(date)
                                Spacer(minLength: 8)
                                cancelPendingButton
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    pendingIcon
                                    pendingText(date)
                                }
                                cancelPendingButton
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowInsets(EdgeInsets(top: 8, leading: 28, bottom: 8, trailing: 28))
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.pendingGround)
                                .padding(.horizontal, 16)
                        )
                        .listRowSeparator(.hidden)
                    }
                }

                Section {
                    ForEach(model.draft.groups) { group in
                        NavigationLink {
                            GroupEditorView(group: group, isNew: false)
                        } label: {
                            GroupRow(group: group,
                                     blockedUntil: model.isBlockedToday(group.id) ? model.active.dayStart.label : nil,
                                     pending: model.hasPendingChange(group.id))
                        }
                    }
                    Button {
                        newGroup = LimitGroup(name: "")
                    } label: {
                        Label("Ajouter une limite", systemImage: "plus")
                    }
                    .sensoryFeedback(.selection, trigger: newGroup?.id)
                } header: {
                    SectionTitle("Limites par jour")
                }

                Section {
                    NavigationLink {
                        DomainsView()
                    } label: {
                        LabeledContent("Sites bloqués", value: "\(model.draft.blockedDomains.count)")
                    }
                } header: {
                    SectionTitle("Sites")
                }

                Section {
                    DatePicker("Nouvelle journée à", selection: dayStartBinding, displayedComponents: .hourAndMinute)
                    Toggle("Empêcher la suppression d'apps", isOn: Binding(
                        get: { model.draft.denyAppRemoval },
                        set: { on in handle(model.setDenyAppRemoval(on)) }
                    ))
                    .tint(Theme.toggle)
                } header: {
                    SectionTitle("Réglages")
                }
            }
            .listStyle(.plain)
            .navigationTitle("Time Keeper")
            .sheet(item: $newGroup) { group in
                NavigationStack {
                    GroupEditorView(group: group, isNew: true)
                }
                .tint(Theme.accent)
            }
            .delayedAlert($delayedUntil)
        }
        .sensoryFeedback(.success, trigger: model.draft)
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
    let blockedUntil: String?
    let pending: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name.isEmpty ? "Sans nom" : group.name).font(.headline)
                if let blockedUntil {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill").accessibilityHidden(true)
                        Text("Bloqué jusqu'à \(blockedUntil)")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.blocked)
                } else if pending {
                    Text("Modification dans 24 h")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.pending)
                } else if !group.isEmpty {
                    Text("\(group.itemCount) élément\(group.itemCount > 1 ? "s" : "")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(formatMinutes(group.minutes))
                .font(Theme.value)
                .accessibilityLabel("\(formatMinutes(group.minutes)) par jour")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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
