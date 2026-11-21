import SwiftUI
import FamilyControls
import UserNotifications

@main
struct TimeKeeperApp: App {
    @StateObject private var model = AppModel(
        demo: ProcessInfo.processInfo.arguments.contains("-demo"),
        demoOnboarding: ProcessInfo.processInfo.arguments.contains("-onboarding")
    )

    init() {
        Theme.applyNavigationTitle()
        LiveLimit.observeTokens()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var auth = AuthorizationCenter.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !model.hasOnboarded {
                OnboardingFlow()
            } else if model.demo || auth.authorizationStatus == .approved {
                MainView()
            } else {
                AccessView()
            }
        }
        .animation(.smooth, value: model.hasOnboarded)
        .tint(Theme.accent)
        .onAppear { model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    let demo: Bool
    @Published private(set) var state: TimeKeeperState
    @Published private(set) var hasOnboarded: Bool
    @Published private(set) var reminderPlan: ReminderPlan
    @Published private(set) var notificationsDenied = false

    private static let onboardedKey = "onboarded.v1"

    init(demo: Bool, demoOnboarding: Bool = false) {
        self.demo = demo || demoOnboarding
        let loaded = demoOnboarding ? TimeKeeperState() : demo ? AppModel.demoState : SharedStorage.load()
        state = loaded
        reminderPlan = demo || demoOnboarding ? .halfAndLastFive : SharedStorage.reminderPlan
        hasOnboarded = demoOnboarding ? false : demo || UserDefaults.standard.bool(forKey: AppModel.onboardedKey) || !loaded.active.isUnrestricted
    }

    func applyOnboarding(_ rules: Rules) {
        save(rules)
    }

    func finishOnboarding() {
        if !demo {
            UserDefaults.standard.set(true, forKey: AppModel.onboardedKey)
        }
        hasOnboarded = true
    }

    var draft: Rules { state.draft }
    var active: Rules { state.active }

    func refresh() {
        if demo { return }
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { return }
        Engine.applyPendingIfDue()
        state = SharedStorage.load()
        if !state.active.groups.isEmpty { Reminder.requestPermission() }
        refreshNotificationStatus()
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let denied = settings.authorizationStatus == .denied
            Task { @MainActor in self.notificationsDenied = denied }
        }
    }

    func setReminderPlan(_ plan: ReminderPlan) {
        reminderPlan = plan
        if demo { return }
        SharedStorage.reminderPlan = plan
        Engine.sync(state.active)
    }

    @discardableResult
    func save(_ rules: Rules) -> SaveOutcome {
        if demo {
            state = Engine.plan(state, draft: rules, now: Date())
            if let date = state.pendingEffective, state.pending != nil { return .delayed(until: date) }
            return .immediate
        }
        let outcome = Engine.save(draft: rules)
        state = SharedStorage.load()
        return outcome
    }

    func upsert(_ group: LimitGroup) -> SaveOutcome {
        var rules = draft
        if let i = rules.groups.firstIndex(where: { $0.id == group.id }) {
            rules.groups[i] = group
        } else {
            rules.groups.append(group)
        }
        return save(rules)
    }

    func deleteGroup(_ id: UUID) -> SaveOutcome {
        var rules = draft
        rules.groups.removeAll { $0.id == id }
        return save(rules)
    }

    func addDomain(_ domain: String) -> SaveOutcome {
        var rules = draft
        if !rules.blockedDomains.contains(domain) { rules.blockedDomains.append(domain) }
        return save(rules)
    }

    func removeDomain(_ domain: String) -> SaveOutcome {
        var rules = draft
        rules.blockedDomains.removeAll { $0 == domain }
        return save(rules)
    }

    func setDenyAppRemoval(_ on: Bool) -> SaveOutcome {
        var rules = draft
        rules.denyAppRemoval = on
        return save(rules)
    }

    func setDayStart(_ dayStart: DayStart) -> SaveOutcome {
        var rules = draft
        rules.dayStart = dayStart
        return save(rules)
    }

    func cancelPending() {
        save(active)
    }

    func isBlockedToday(_ id: UUID) -> Bool {
        if demo { return state.active.groups.first?.id == id }
        return SharedStorage.isShieldedToday(id)
    }

    func hasPendingChange(_ id: UUID) -> Bool {
        guard state.pending != nil else { return false }
        return draft.groups.first(where: { $0.id == id }) != active.groups.first(where: { $0.id == id })
    }

    func isDomainPendingRemoval(_ domain: String) -> Bool {
        state.pending != nil && active.blockedDomains.contains(domain) && !draft.blockedDomains.contains(domain)
    }

    private static var demoState: TimeKeeperState {
        var rules = Rules()
        rules.groups = [
            LimitGroup(name: "Réseaux sociaux", minutes: 30),
            LimitGroup(name: "Vidéo", minutes: 45),
            LimitGroup(name: "Jeux", minutes: 20),
        ]
        rules.blockedDomains = ["youtube.com", "instagram.com", "tiktok.com"]
        rules.denyAppRemoval = true
        rules.dayStart = DayStart(hour: 4, minute: 0)
        return TimeKeeperState(active: rules)
    }
}
