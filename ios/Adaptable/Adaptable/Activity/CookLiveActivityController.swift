import Foundation
import ActivityKit

enum CookLiveActivityController {
    static var currentRecipeId: String? {
        Activity<CookActivityAttributes>.activities.first?.attributes.recipeId
    }

    static var currentStepIndex: Int? {
        Activity<CookActivityAttributes>.activities.first?.content.state.stepIndex
    }

    static var currentTimerEndsAt: Date? {
        Activity<CookActivityAttributes>.activities.first?.content.state.timerEndsAt
    }

    @discardableResult
    static func start(recipe: Recipe, stepLabel: String, step: Int, total: Int, timerEndsAt: Date?) -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        let attributes = CookActivityAttributes(
            recipeId: recipe.id,
            recipeTitle: recipe.title ?? "Cooking",
            emoji: recipe.emoji ?? "🍳"
        )
        let state = CookActivityAttributes.ContentState(
            stepLabel: stepLabel,
            stepIndex: step,
            totalSteps: total,
            timerEndsAt: timerEndsAt,
            timerLabel: timerEndsAt == nil ? "Cook Mode" : "Timer running"
        )
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            return activity.id
        } catch {
            print("[CookLiveActivity] start failed: \(error)")
            return nil
        }
    }

    static func update(stepLabel: String, step: Int, total: Int, timerEndsAt: Date?) {
        let state = CookActivityAttributes.ContentState(
            stepLabel: stepLabel,
            stepIndex: step,
            totalSteps: total,
            timerEndsAt: timerEndsAt,
            timerLabel: timerEndsAt == nil ? "Cook Mode" : "Timer running"
        )
        Task {
            for activity in Activity<CookActivityAttributes>.activities {
                await activity.update(.init(state: state, staleDate: nil))
            }
        }
    }

    static func end() {
        Task {
            for activity in Activity<CookActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
