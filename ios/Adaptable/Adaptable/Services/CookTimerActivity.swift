import ActivityKit
import Foundation

/// Starts / updates / ends the cook-timer Live Activity. Without a Widget
/// Extension the request is a no-op (or fails quietly); lock-screen banners
/// still fire via `Alarm.scheduleTimerNotification`.
@MainActor
enum CookTimerLiveActivity {
    /// Chains create work so overlapping `sync` calls cannot end a just-requested activity.
    private static var syncTask: Task<Void, Never>?

    static func sync(
        recipeTitle: String,
        emoji: String,
        timers: [(label: String, endsAt: Date, step: Int, totalSeconds: Int)],
        totalSteps: Int
    ) {
        let now = Date()
        let live = timers
            .filter { $0.endsAt > now }
            .sorted { $0.endsAt < $1.endsAt }

        guard !live.isEmpty else {
            endAll()
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let soonest = live[0]
        let startedAt = soonest.endsAt.addingTimeInterval(-TimeInterval(max(soonest.totalSeconds, 1)))
        let state = CookTimerAttributes.ContentState(
            label: soonest.label,
            startedAt: startedAt,
            endsAt: soonest.endsAt,
            step: soonest.step,
            totalSteps: totalSteps,
            extraCount: max(0, live.count - 1)
        )
        let attributes = CookTimerAttributes(
            recipeName: recipeTitle,
            emoji: emoji.isEmpty ? "🍳" : emoji
        )

        let activities = Activity<CookTimerAttributes>.activities
        if let existing = activities.first(where: {
            $0.attributes.recipeName == attributes.recipeName
                && $0.attributes.emoji == attributes.emoji
        }) {
            Task { await existing.update(ActivityContent(state: state, staleDate: soonest.endsAt)) }
            for other in activities where other.id != existing.id {
                Task { await other.end(nil, dismissalPolicy: .immediate) }
            }
        } else {
            let previous = syncTask
            syncTask = Task {
                await previous?.value
                let activities = Activity<CookTimerAttributes>.activities
                if let existing = activities.first(where: {
                    $0.attributes.recipeName == attributes.recipeName
                        && $0.attributes.emoji == attributes.emoji
                }) {
                    await existing.update(ActivityContent(state: state, staleDate: soonest.endsAt))
                    for other in activities where other.id != existing.id {
                        await other.end(nil, dismissalPolicy: .immediate)
                    }
                    return
                }
                for activity in activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                do {
                    _ = try Activity.request(
                        attributes: attributes,
                        content: ActivityContent(state: state, staleDate: soonest.endsAt),
                        pushType: nil
                    )
                } catch {
                    print("[CookTimerLiveActivity] request failed: \(error)")
                }
            }
        }
    }

    static func endAll() {
        for activity in Activity<CookTimerAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
