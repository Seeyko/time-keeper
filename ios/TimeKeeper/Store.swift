import Foundation
import StoreKit
import UserNotifications

enum Plan: String, CaseIterable, Identifiable, Sendable {
    case yearly = "com.seeyko.timekeeper.annuel"
    case lifetime = "com.seeyko.timekeeper.vie"

    static let trialDays = 7
    static let trialReminderDay = 5

    var id: String { rawValue }

    var name: String {
        switch self {
        case .yearly: "1 an"
        case .lifetime: "À vie"
        }
    }

    func cta(trial: Bool) -> String {
        self == .yearly && trial ? "Essayer \(Plan.trialDays) jours gratuits" : "Continuer"
    }

    func terms(price: String, trial: Bool) -> String {
        switch self {
        case .yearly: trial ? "Puis \(price) par an. Annulable à tout moment." : "\(price) par an. Annulable à tout moment."
        case .lifetime: "\(price) une seule fois. Aucun abonnement."
        }
    }
}

extension Product.PurchaseResult {
    var outcome: String {
        switch self {
        case .pending: "purchase_pending"
        case .userCancelled: "purchase_cancelled"
        default: "purchase_unverified"
        }
    }
}

@MainActor
final class Store: ObservableObject {
    enum Access: Equatable {
        case unknown, granted, none
    }

    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://github.com/Seeyko/time-keeper/blob/main/PRIVACY.md")!

    @Published private(set) var access: Access
    @Published private(set) var products: [Plan: Product] = [:]
    @Published private(set) var trialEligible = true
    @Published private(set) var purchasing: Plan?

    private let demo: Bool
    private var updates: Task<Void, Never>?
    private static let grantedKey = "access.granted.v1"

    init(demo: Bool, paywall: Bool) {
        self.demo = demo
        if demo {
            access = paywall ? .none : .granted
        } else {
            access = UserDefaults.standard.bool(forKey: Store.grantedKey) ? .granted : .unknown
        }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        if products.count < Plan.allCases.count,
           let loaded = try? await Product.products(for: Plan.allCases.map(\.rawValue)) {
            products = Dictionary(uniqueKeysWithValues: loaded.compactMap { product in
                Plan(rawValue: product.id).map { ($0, product) }
            })
        }
        if let subscription = products[.yearly]?.subscription {
            trialEligible = await subscription.isEligibleForIntroOffer
        }
        var granted = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, Plan(rawValue: transaction.productID) != nil, transaction.revocationDate == nil {
                granted = true
            }
        }
        if demo && !granted { return }
        setAccess(granted ? .granted : .none)
    }

    func purchase(_ plan: Plan) async {
        guard let product = products[plan], purchasing == nil else { return }
        purchasing = plan
        defer { purchasing = nil }
        Analytics.capture("purchase_started", ["product_id": plan.rawValue])
        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            Analytics.capture("purchase_failed", ["product_id": plan.rawValue, "error": String(describing: error)])
            return
        }
        guard case .success(.verified(let transaction)) = result else {
            Analytics.capture(result.outcome, ["product_id": plan.rawValue])
            return
        }
        let trial = transaction.offer?.type == .introductory
        if trial {
            scheduleTrialReminder(from: transaction.purchaseDate)
        }
        Analytics.capture(trial ? "trial_started" : "purchase_completed", [
            "product_id": plan.rawValue,
            "revenue": trial ? 0 : NSDecimalNumber(decimal: product.price).doubleValue,
            "currency": product.priceFormatStyle.currencyCode,
        ], person: ["plan": plan.rawValue])
        await transaction.finish()
        await refresh()
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
        Analytics.capture("purchase_restored", ["found": access == .granted])
    }

    private func setAccess(_ value: Access) {
        if access != value, value != .unknown {
            Analytics.capture("access_changed", ["access": value == .granted ? "granted" : "none"], person: ["acces": value == .granted])
        }
        access = value
        if demo { return }
        UserDefaults.standard.set(value == .granted, forKey: Store.grantedKey)
        let suspended = value == .none
        guard SharedStorage.suspended != suspended else { return }
        SharedStorage.suspended = suspended
        Engine.sync(SharedStorage.load().active)
    }

    private func scheduleTrialReminder(from start: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Ton essai finit dans \(Plan.trialDays - Plan.trialReminderDay) jours"
        content.body = "Rien à faire pour continuer. Pour arrêter, annule dans les Réglages."
        let fire = start.addingTimeInterval(TimeInterval(Plan.trialReminderDay * 86_400))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, fire.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "trial.end", content: content, trigger: trigger))
    }
}
