import WidgetKit
import SwiftUI
import ActivityKit

/// Drop-in Live Activity UI for cook timers.
///
/// This file is *outside* the app's synchronized source group so it is not
/// compiled into the main target. To ship Dynamic Island / Lock Screen
/// timers: Xcode → File → New → Target → Widget Extension, enable Live
/// Activity, then add this folder to that target (and `CookTimerAttributes`
/// from the app target, or copy the attributes struct identically).

struct CookTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookTimerAttributes.self) { context in
            HStack(spacing: 12) {
                Text(context.attributes.emoji)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.recipeName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.state.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                    .font(.title2.monospacedDigit().weight(.heavy))
                    .multilineTextAlignment(.trailing)
            }
            .padding(16)
            .activityBackgroundTint(Color.orange.opacity(0.18))
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
