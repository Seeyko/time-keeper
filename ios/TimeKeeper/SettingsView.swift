import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var delayedUntil: Date?
    @State private var feedback = false
    @State private var analytics = Analytics.enabled
    @Environment(\.openURL) private var openURL

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image("owl-garde")
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                        .frame(width: 60, height: 60)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Time Keeper")
                            .font(Theme.section)
                        Text("Version \(version)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            Section {
                DatePicker(selection: dayStartBinding, displayedComponents: .hourAndMinute) {
                    TileLabel("Remise à zéro à", symbol: "arrow.counterclockwise", tint: Theme.toggle)
                }
                Toggle(isOn: Binding(
                    get: { model.draft.denyAppRemoval },
                    set: { on in handle(model.setDenyAppRemoval(on)) }
                )) {
                    TileLabel("Verrouiller la suppression d'apps", symbol: "lock.fill", tint: Theme.bark)
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { model.reminders.atHalf },
                    set: { on in var r = model.reminders; r.atHalf = on; model.setReminders(r) }
                )) {
                    TileLabel("Me prévenir à la moitié", symbol: "bell.fill", tint: Theme.ochre)
                }
                Picker(selection: Binding(
                    get: { model.reminders.minutesBefore },
                    set: { m in var r = model.reminders; r.minutesBefore = m; model.setReminders(r) }
                )) {
                    ForEach(ReminderSettings.beforeChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? "Jamais" : "\(minutes) min").tag(minutes)
                    }
                } label: {
                    TileLabel("Me prévenir avant la fin", symbol: "timer", tint: Theme.ochre)
                }
                if model.notificationsDenied && (model.reminders.atHalf || model.reminders.minutesBefore > 0) {
                    Button("Autoriser les notifications") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .foregroundStyle(Theme.accent)
                    .frame(minHeight: 44)
                }
            }

            Section {
                Toggle(isOn: $analytics) {
                    TileLabel("Statistiques anonymes", symbol: "chart.bar.fill", tint: Theme.slate)
                }
                .onChange(of: analytics) { _, on in Analytics.enabled = on }
                Button {
                    feedback = true
                } label: {
                    HStack {
                        TileLabel("Ton avis", symbol: "envelope.fill", tint: Theme.blush)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .groupedScreen()
        .tint(Theme.toggle)
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.large)
        .sensoryFeedback(.selection, trigger: model.reminders)
        .sensoryFeedback(.selection, trigger: analytics)
        .sensoryFeedback(.selection, trigger: feedback)
        .sheet(isPresented: $feedback) {
            NavigationStack { FeedbackView() }
                .tint(Theme.accent)
        }
        .delayedAlert($delayedUntil)
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
