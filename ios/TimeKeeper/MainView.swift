import SwiftUI
import FamilyControls

struct MainView: View {
    @EnvironmentObject private var model: AppModel
    @State private var delayedUntil: Date?
    @State private var newGroup: LimitGroup?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.openURL) private var openURL

    private var pendingIcon: some View {
        Image(systemName: "clock")
            .font(.title3)
            .foregroundStyle(Theme.pending)
            .accessibilityHidden(true)
    }

    private func pendingText(_ date: Date) -> some View {
        Text("Changement prévu le \(date.formatted(date: .abbreviated, time: .shortened))")
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var cancelPendingButton: some View {
        Button("Annuler") { model.cancelPending() }
            .buttonStyle(.borderless)
            .font(.callout.weight(.semibold))
            .foregroundStyle(Theme.pending)
            .frame(minHeight: 44)
            .accessibilityLabel("Annuler ce changement")
    }

    var body: some View {
        NavigationStack {
            List {
                if let date = model.state.pendingEffective, model.state.pending != nil {
                    Section {
                        Group {
                            if typeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        pendingIcon
                                        pendingText(date)
                                    }
                                    cancelPendingButton
                                }
                            } else {
                                HStack(spacing: 12) {
                                    pendingIcon
                                    pendingText(date)
                                    Spacer(minLength: 8)
                                    cancelPendingButton
                                }
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
                    DatePicker("Remise à zéro à", selection: dayStartBinding, displayedComponents: .hourAndMinute)
                    Toggle("Verrouiller la suppression d'apps", isOn: Binding(
                        get: { model.draft.denyAppRemoval },
                        set: { on in handle(model.setDenyAppRemoval(on)) }
                    ))
                    .tint(Theme.toggle)
                    Toggle("Me prévenir à la moitié", isOn: Binding(
                        get: { model.reminders.atHalf },
                        set: { on in var r = model.reminders; r.atHalf = on; model.setReminders(r) }
                    ))
                    .tint(Theme.toggle)
                    Picker("Me prévenir avant la fin", selection: Binding(
                        get: { model.reminders.minutesBefore },
                        set: { m in var r = model.reminders; r.minutesBefore = m; model.setReminders(r) }
                    )) {
                        ForEach(ReminderSettings.beforeChoices, id: \.self) { minutes in
                            Text(minutes == 0 ? "Jamais" : "\(minutes) min avant").tag(minutes)
                        }
                    }
                    .sensoryFeedback(.selection, trigger: model.reminders)
                    if model.notificationsDenied && (model.reminders.atHalf || model.reminders.minutesBefore > 0) {
                        Button("Autoriser les notifications") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .foregroundStyle(Theme.accent)
                        .frame(minHeight: 44)
                    }
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
                    Text("Changement en attente")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.pending)
                } else if !group.isEmpty {
                    Text(group.contentLabel)
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

extension LimitGroup {
    var contentLabel: String {
        let parts = [
            counted(selection.applicationTokens.count, "app", "apps"),
            counted(selection.categoryTokens.count, "catégorie", "catégories"),
            counted(selection.webDomainTokens.count, "site", "sites"),
        ].compactMap { $0 }
        return parts.joined(separator: " · ")
    }

    private func counted(_ count: Int, _ one: String, _ many: String) -> String? {
        count == 0 ? nil : "\(count) \(count > 1 ? many : one)"
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
            Text("Ce changement s'applique le \(date.wrappedValue?.formatted(date: .abbreviated, time: .shortened) ?? "").")
        }
    }
}
