import ActivityKit
import Foundation

/// Must stay identical to `Adaptable/Services/CookTimerAttributes.swift`.
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
