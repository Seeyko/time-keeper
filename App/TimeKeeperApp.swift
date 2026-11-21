import SwiftUI
import FamilyControls

@main
struct TimeKeeperApp: App {
    @StateObject private var model = AppModel()

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
            if auth.authorizationStatus == .approved {
                MainView()
            } else {
                OnboardingView()
            }
        }
        .onAppear { model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state = SharedStorage.load()

    var draft: Rules { state.draft }
    var active: Rules { state.active }

    func refresh() {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { return }
        Engine.applyPendingIfDue()
        state = SharedStorage.load()
    }

    @discardableResult
    func save(_ rules: Rules) -> SaveOutcome {
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

    /// Renonce aux assouplissements en attente (toujours autorisé : c'est plus strict).
    func cancelPending() {
        save(active)
    }

    func isBlockedToday(_ id: UUID) -> Bool {
        SharedStorage.isShieldedToday(id)
    }

    /// Vrai si cette limite va changer quand le délai sera écoulé.
    func hasPendingChange(_ id: UUID) -> Bool {
        guard state.pending != nil else { return false }
        return draft.groups.first(where: { $0.id == id }) != active.groups.first(where: { $0.id == id })
    }

    func isDomainPendingRemoval(_ domain: String) -> Bool {
        state.pending != nil && active.blockedDomains.contains(domain) && !draft.blockedDomains.contains(domain)
    }
}
