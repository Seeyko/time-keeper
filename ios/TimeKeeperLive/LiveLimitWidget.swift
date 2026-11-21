import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TimeKeeperLiveBundle: WidgetBundle {
    var body: some Widget {
        LiveLimitWidget()
    }
}

struct LiveLimitWidget: Widget {
    private let night = Color(red: 0.043, green: 0.082, blue: 0.188)
    private let gold = Color(red: 0.96, green: 0.76, blue: 0.32)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveLimitAttributes.self) { context in
            HStack(spacing: 14) {
                owl.frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.name).font(.headline)
                    Text(remainingText(context.state.remaining)).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                gauge(context.state)
            }
            .padding(16)
            .activityBackgroundTint(night)
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    owl.frame(width: 44, height: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    gauge(context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.name).font(.headline)
                        Text(remainingText(context.state.remaining)).font(.subheadline).foregroundStyle(gold)
                    }
                }
            } compactLeading: {
                owl.frame(width: 22, height: 22)
            } compactTrailing: {
                Text("\(context.state.remaining) min")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(gold)
            } minimal: {
                owl.frame(width: 22, height: 22)
            }
        }
    }

    private var owl: some View {
        Image("owl-patient").resizable().scaledToFit().accessibilityHidden(true)
    }

    private func remainingText(_ remaining: Int) -> String {
        remaining <= 0 ? "Bloqué jusqu'à demain" : "Il te reste \(remaining) min"
    }

    private func gauge(_ state: LiveLimitAttributes.ContentState) -> some View {
        Gauge(value: Double(max(state.remaining, 0)), in: 0...Double(max(state.limit, 1))) {
            EmptyView()
        } currentValueLabel: {
            Text("\(state.remaining)").font(.caption.weight(.semibold)).monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(gold)
        .frame(width: 44, height: 44)
    }
}
