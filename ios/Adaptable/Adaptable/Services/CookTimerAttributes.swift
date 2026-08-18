import ActivityKit
import Foundation

/// Shared Live Activity attributes. Add this file to both the app target and
/// a Widget Extension target so the lock-screen UI can decode the activity
/// the app starts.
struct CookTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var label: String
        var startedAt: Date
        var endsAt: Date
        var step: Int
        var totalSteps: Int
        var extraCount: Int
    }

    var recipeName: String
    var emoji: String
}
