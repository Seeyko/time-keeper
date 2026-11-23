import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var plan: Plan = .yearly
    @State private var redeeming = false
    @State private var taps = 0
    @Namespace private var selection

    private var trial: Bool { plan == .yearly && store.trialEligible }
    private var motion: Animation { reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.4) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    Image("owl-garde")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .accessibilityHidden(true)
                    Text("Tes limites tiennent, pour de bon.")
                        .font(Theme.heading)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    if trial {
                        TrialTimeline()
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    }
                    VStack(spacing: 10) {
                        ForEach(Plan.allCases) { option in
                            PlanRow(
                                plan: option,
                                price: store.products[option]?.displayPrice,
                                badge: option == .yearly && store.trialEligible ? "\(Plan.trialDays) jours offerts" : nil,
                                selected: plan == option,
                                selection: selection
                            ) {
                                withAnimation(motion) { plan = option }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            footer
        }
        .animation(motion, value: store.trialEligible)
        .sensoryFeedback(.impact(weight: .light), trigger: plan)
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .sensoryFeedback(trigger: store.access) { _, now in now == .granted ? .success : nil }
        .offerCodeRedemption(isPresented: $redeeming) { _ in
            Task { await store.refresh() }
        }
        .task {
            await store.refresh()
            Analytics.capture("paywall_viewed", ["trial_eligible": store.trialEligible])
        }
        .onChange(of: plan) { _, option in
            Analytics.capture("paywall_plan_selected", ["product_id": option.rawValue])
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button {
                taps += 1
                Task { await store.purchase(plan) }
            } label: {
                ZStack {
                    Text(plan.cta(trial: trial))
                        .contentTransition(.opacity)
                        .opacity(store.purchasing == nil ? 1 : 0)
                    if store.purchasing != nil { ProgressView().tint(Theme.onAccent) }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(store.products[plan] == nil || store.purchasing != nil)
            Text(store.products[plan].map { plan.terms(price: $0.displayPrice, trial: trial) } ?? " ")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
            HStack(spacing: 14) {
                Button("Restaurer") { Task { await store.restore() } }
                Button("J'ai un code") {
                    redeeming = true
                    Analytics.capture("offer_code_opened")
                }
                Button("Conditions") { openURL(Store.terms) }
                Button("Confidentialité") { openURL(Store.privacy) }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(minHeight: 44)
            .sensoryFeedback(.selection, trigger: redeeming)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}

private struct TrialTimeline: View {
    private let steps = [
        ("Aujourd'hui", "Tout est ouvert"),
        ("Jour \(Plan.trialReminderDay)", "Je te rappelle la fin de l'essai"),
        ("Jour \(Plan.trialDays)", "Premier paiement, sauf si tu annules"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(index == 0 ? Theme.accent : Theme.hairline)
                            .frame(width: 12, height: 12)
                            .padding(.top, 4)
                        if index < steps.count - 1 {
                            Rectangle().fill(Theme.hairline).frame(width: 2).frame(minHeight: 30)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.0).font(.subheadline.weight(.semibold))
                        Text(step.1).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 10)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct PlanRow: View {
    let plan: Plan
    let price: String?
    let badge: String?
    let selected: Bool
    let selection: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accent : Theme.hairline)
                    .contentTransition(.symbolEffect(.replace))
                Text(plan.name).font(.headline)
                if let badge {
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(Theme.onAccent)
                        .background(Theme.accent, in: Capsule())
                }
                Spacer()
                Text(price ?? "–").font(Theme.value)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.accentGround)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.accent, lineWidth: 2)
                        )
                        .matchedGeometryEffect(id: "plan", in: selection)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
