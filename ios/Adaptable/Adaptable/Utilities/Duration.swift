import Foundation

/// Pull a cook-timer duration out of instruction text so every step with
/// "sear 4 minutes" or "boil eggs 6½ minutes" gets a one-tap timer.
/// Mirrors `src/lib/duration.ts`.
enum DurationParser {
    private static let unitSeconds: [String: Double] = [
        "hour": 3600, "hr": 3600, "minute": 60, "min": 60, "second": 1, "sec": 1,
    ]

    static func extractTimerSeconds(_ text: String) -> Int? {
        var normalized = text
        normalized = replaceUnicodeFraction(in: normalized, symbol: "½", value: ".5")
        normalized = replaceUnicodeFraction(in: normalized, symbol: "¼", value: ".25")
        normalized = replaceUnicodeFraction(in: normalized, symbol: "¾", value: ".75")

        // Clock style: "6:30"
        if let m = firstMatch(#"\b(\d{1,2}):([0-5]\d)\b"#, in: normalized) {
            let mins = Int(m[0]) ?? 0
            let secs = Int(m[1]) ?? 0
            let total = mins * 60 + secs
            if total >= 10 && total <= 6 * 3600 { return total }
        }

        // "4 minutes", "2-3 minutes", "90 seconds", "1 hour"
        let pattern = #"(\d+(?:\.\d+)?)\s*(?:[-–—]|to\s+)?\s*(\d+(?:\.\d+)?)?\s*(hours?|hrs?|minutes?|mins?|seconds?|secs?)\b"#
        guard let m = firstMatch(pattern, in: normalized, optionalGroups: [1]) else { return nil }
        let lower = (m[1].isEmpty ? m[0] : m[1])
        guard let upper = Double(lower) else { return nil }
        var unitKey = m[2].lowercased()
        if unitKey.hasSuffix("s") { unitKey.removeLast() }
        guard let mult = unitSeconds[unitKey] else { return nil }
        let secs = Int((upper * mult).rounded())
        guard secs >= 10 && secs <= 6 * 3600 else { return nil }
        return secs
    }

    static func formatClock(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private static func replaceUnicodeFraction(in text: String, symbol: String, value: String) -> String {
        guard let re = try? NSRegularExpression(pattern: #"(\d+)\s*"# + NSRegularExpression.escapedPattern(for: symbol)) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return re.stringByReplacingMatches(in: text, range: range, withTemplate: "$1" + value)
    }

    /// Returns capture groups by index; empty string for groups that didn't
    /// participate in the match (mirrors JS's `undefined` capture groups).
    private static func firstMatch(_ pattern: String, in text: String, optionalGroups: Set<Int> = []) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range) else { return nil }
        var groups: [String] = []
        for i in 1..<m.numberOfRanges {
            guard let r = Range(m.range(at: i), in: text) else {
                groups.append("")
                continue
            }
            groups.append(String(text[r]))
        }
        return groups
    }
}
