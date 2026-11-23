import SwiftUI
import FamilyControls

struct MainView: View {
    @EnvironmentObject private var model: AppModel
    @State private var newGroup: LimitGroup?
    @State private var settings = ProcessInfo.processInfo.arguments.contains("-settings")
    @State private var sites = ProcessInfo.processInfo.arguments.contains("-sites")
    @Environment(\.dynamicTypeSize) private var typeSize

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
                        .listRowBackground(Theme.pendingGround)
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
                        Label {
                            Text("Ajouter une limite")
                        } icon: {
                            Tile(symbol: "plus", tint: Theme.toggle)
                        }
                    }
                    .sensoryFeedback(.selection, trigger: newGroup?.id)
                } header: {
                    Text("Limites par jour")
                }

                Section {
                    NavigationLink {
                        DomainsView()
                    } label: {
                        LabeledContent {
                            Text("\(model.draft.blockedDomains.count)")
                        } label: {
                            TileLabel("Sites bloqués", symbol: "globe", tint: Theme.blush)
                        }
                    }
                } header: {
                    Text("Sites")
                }

                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        TileLabel("Réglages", symbol: "gearshape.fill", tint: Theme.slate)
                    }
                }
            }
            .groupedScreen()
            .sheet(item: $newGroup) { group in
                NavigationStack {
                    GroupEditorView(group: group, isNew: true)
                }
                .tint(Theme.accent)
            }
            .navigationDestination(isPresented: $settings) { SettingsView() }
            .navigationDestination(isPresented: $sites) { DomainsView() }
        }
        .sensoryFeedback(.success, trigger: model.draft)
    }
}

private struct GroupRow: View {
    let group: LimitGroup
    let blockedUntil: String?
    let pending: Bool

    var body: some View {
        LabeledContent {
            Text(formatMinutes(group.minutes))
                .monospacedDigit()
                .accessibilityLabel("\(formatMinutes(group.minutes)) par jour")
        } label: {
            Label {
                details
            } icon: {
                Tile(symbol: blockedUntil == nil ? "clock.fill" : "lock.fill",
                     tint: blockedUntil == nil ? Theme.toggle : Theme.blocked)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(group.name.isEmpty ? "Sans nom" : group.name)
            if let blockedUntil {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill").accessibilityHidden(true)
                    Text("Bloqué jusqu'à \(blockedUntil)")
                }
                .font(.subheadline)
                .foregroundStyle(Theme.blocked)
            } else if pending {
                Text("Changement en attente")
                    .font(.subheadline)
                    .foregroundStyle(Theme.pending)
            } else if !group.isEmpty {
                Text(group.contentLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
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
