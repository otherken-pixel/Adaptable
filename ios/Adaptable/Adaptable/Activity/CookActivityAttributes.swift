import Foundation
import ActivityKit

struct CookActivityAttributes: ActivityAttributes {
    var recipeId: String
    var recipeTitle: String
    var emoji: String

    struct ContentState: Codable, Hashable {
        var stepLabel: String
        var stepIndex: Int
        var totalSteps: Int
        var timerEndsAt: Date?
        var timerLabel: String
    }
}
