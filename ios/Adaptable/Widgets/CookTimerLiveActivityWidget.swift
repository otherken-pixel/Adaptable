import WidgetKit
import SwiftUI
import ActivityKit

/// Lock Screen + Dynamic Island UI for `CookTimerAttributes` (multi-timer).
struct CookTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookTimerAttributes.self) { context in
            HStack(spacing: 12) {
                Text(context.attributes.emoji)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.recipeName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(context.state.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer()
                Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                    .font(.title2.monospacedDigit().weight(.heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
            }
            .padding(16)
            .kitchenActivitySurface()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.emoji).font(.title)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.recipeName).font(.headline).lineLimit(1)
                        Text("Step \(context.state.step) of \(context.state.totalSteps) · \(context.state.label)")
                            .font(.caption.weight(.semibold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                        .font(.title3.monospacedDigit().weight(.bold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.extraCount > 0 {
                        Text("+\(context.state.extraCount) more timer\(context.state.extraCount == 1 ? "" : "s") running")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Text(context.attributes.emoji)
            } compactTrailing: {
                Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
            } minimal: {
                Text(context.attributes.emoji)
            }
        }
    }
}
