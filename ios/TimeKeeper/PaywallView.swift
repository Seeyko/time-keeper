import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var plan: Plan = .yearly
    @State private var redeeming = false
    @State private var taps = 0

    private var trial: Bool { plan == .yearly && store.trialEligible }

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
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    VStack(spacing: 10) {
                        ForEach(Plan.allCases) { option in
                            PlanRow(
                                plan: option,
                                price: store.products[option]?.displayPrice,
                                badge: option == .yearly && store.trialEligible ? "\(Plan.trialDays) jours offerts" : nil,
                                selected: plan == option
                            ) { plan = option }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            footer
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.45), value: trial)
        .sensoryFeedback(.impact(weight: .light), trigger: plan)
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .sensoryFeedback(trigger: store.access) { _, now in now == .granted ? .success : nil }
        .offerCodeRedemption(isPresented: $redeeming) { _ in
            Task { await store.refresh() }
        }
        .task { await store.refresh() }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button {
                taps += 1
                Task { await store.purchase(plan) }
            } label: {
                ZStack {
                    Text(plan.cta(trial: trial)).opacity(store.purchasing == nil ? 1 : 0)
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
                .animation(.easeInOut(duration: 0.2), value: plan)
            HStack(spacing: 14) {
                Button("Restaurer") { Task { await store.restore() } }
                Button("J'ai un code") { redeeming = true }
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accent : Theme.hairline)
                    .scaleEffect(selected ? 1 : 0.9)
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: selected)
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
            .background(selected ? Theme.accentGround : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Theme.accent : Theme.hairline, lineWidth: selected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
