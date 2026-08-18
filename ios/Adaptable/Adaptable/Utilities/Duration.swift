import Foundation

/// A single startable cook timer pulled from instruction text or structured
/// step data. One step can have several (sear 4 min, then cook 3 min).
struct ExtractedTimer: Equatable, Identifiable, Hashable {
    enum Kind: String, Equatable, Hashable {
        case preheat, bake, broil, sear, boil, simmer, rest, marinate, other
    }

    let seconds: Int
    let label: String
    let kind: Kind

    var id: String { "\(kind.rawValue)-\(label)-\(seconds)" }

    var systemImage: String {
        switch kind {
        case .preheat: return "thermometer.sun"
        case .bake, .broil: return "flame.fill"
        case .sear: return "flame"
        case .boil, .simmer: return "drop.fill"
        case .rest, .marinate: return "pause.circle"
        case .other: return "timer"
        }
    }
}

/// Pull cook-timer durations, oven temperatures, and preheat hints out of
/// instruction text. Mirrors `src/lib/duration.ts`, extended so a step with
/// "sear 4 minutes … cook 3 more minutes" gets both timers.
enum DurationParser {
    private static let unitSeconds: [String: Double] = [
        "hour": 3600, "hr": 3600, "minute": 60, "min": 60, "second": 1, "sec": 1,
    ]

    /// First duration only — kept for call sites that still want a single value.
    static func extractTimerSeconds(_ text: String) -> Int? {
        extractAllTimers(from: text).first?.seconds
    }

    static func extractAllTimers(from text: String) -> [ExtractedTimer] {
        var normalized = text
        normalized = replaceUnicodeFraction(in: normalized, symbol: "½", value: ".5")
        normalized = replaceUnicodeFraction(in: normalized, symbol: "¼", value: ".25")
        normalized = replaceUnicodeFraction(in: normalized, symbol: "¾", value: ".75")

        var found: [ExtractedTimer] = []
        var consumed = IndexSet()

        // "4 minutes", "2-3 minutes", "90 seconds", "1 hour"
        let pattern = #"(\d+(?:\.\d+)?)\s*(?:[-–—]|to\s+)?\s*(\d+(?:\.\d+)?)?\s*(hours?|hrs?|minutes?|mins?|seconds?|secs?)\b"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return found
        }
        let ns = normalized as NSString
        let full = NSRange(location: 0, length: ns.length)
        for m in re.matches(in: normalized, options: [], range: full) {
            let overlap = (m.range.location..<(m.range.location + m.range.length))
            if overlap.contains(where: { consumed.contains($0) }) { continue }

            let g1 = ns.substring(with: m.range(at: 1))
            let g2 = m.range(at: 2).location == NSNotFound ? "" : ns.substring(with: m.range(at: 2))
            let unitRaw = ns.substring(with: m.range(at: 3))
            let lower = g2.isEmpty ? g1 : g2
            guard let upper = Double(lower) else { continue }
            var unitKey = unitRaw.lowercased()
            if unitKey.hasSuffix("s") { unitKey.removeLast() }
            guard let mult = unitSeconds[unitKey] else { continue }
            let secs = Int((upper * mult).rounded())
            guard secs >= 10 && secs <= 6 * 3600 else { continue }

            let prefixStart = max(0, m.range.location - 28)
            let prefix = ns.substring(with: NSRange(location: prefixStart, length: m.range.location - prefixStart))
            let (label, kind) = labelAndKind(prefix: prefix, match: ns.substring(with: m.range))
            found.append(ExtractedTimer(seconds: secs, label: label, kind: kind))
            overlap.forEach { consumed.insert($0) }
        }

        // Clock style: "6:30" — only if we didn't already pick up a duration.
        if found.isEmpty, let m = firstMatch(#"\b(\d{1,2}):([0-5]\d)\b"#, in: normalized) {
            let mins = Int(m[0]) ?? 0
            let secs = Int(m[1]) ?? 0
            let total = mins * 60 + secs
            if total >= 10 && total <= 6 * 3600 {
                found.append(ExtractedTimer(seconds: total, label: "Timer", kind: .other))
            }
        }

        return dedupe(found)
    }

    static func extractTemperature(_ text: String) -> String? {
        let pattern = #"(\d{2,3})\s*°\s*([FC])(?:\s*\(\s*(\d{2,3})\s*°\s*([FC])\s*\))?"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let a = ns.substring(with: m.range(at: 1))
        let au = ns.substring(with: m.range(at: 2)).uppercased()
        if m.range(at: 3).location != NSNotFound {
            let b = ns.substring(with: m.range(at: 3))
            let bu = ns.substring(with: m.range(at: 4)).uppercased()
            return "\(a)°\(au) (\(b)°\(bu))"
        }
        return "\(a)°\(au)"
    }

    static func mentionsPreheat(_ text: String) -> Bool {
        text.range(of: #"\bpre-?heat"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Typical time for a home oven to reach 350–425°F from cold.
    static let defaultPreheatSeconds = 10 * 60

    static func formatClock(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    // MARK: - Internals

    private static func labelAndKind(prefix: String, match: String) -> (String, ExtractedTimer.Kind) {
        let blob = (prefix + " " + match).lowercased()
        let pairs: [(String, String, ExtractedTimer.Kind)] = [
            ("preheat", "Oven preheat", .preheat),
            ("pre-heat", "Oven preheat", .preheat),
            ("broil", "Broil", .broil),
            ("grill", "Grill", .broil),
            ("air-fry", "Air-fry", .bake),
            ("air fry", "Air-fry", .bake),
            ("roast", "Roast", .bake),
            ("bake", "Bake", .bake),
            ("sear", "Sear", .sear),
            ("brown", "Brown", .sear),
            ("simmer", "Simmer", .simmer),
            ("boil", "Boil", .boil),
            ("blanch", "Blanch", .boil),
            ("marinate", "Marinate", .marinate),
            ("rest", "Rest", .rest),
            ("whisk", "Whisk", .other),
            ("fry", "Fry", .sear),
            ("cook", "Cook", .other),
        ]
        for (needle, label, kind) in pairs where blob.contains(needle) {
            return (label, kind)
        }
        if blob.contains("last") { return ("Finish", .broil) }
        return ("Step timer", .other)
    }

    private static func dedupe(_ timers: [ExtractedTimer]) -> [ExtractedTimer] {
        var seen = Set<String>()
        return timers.filter { seen.insert($0.id).inserted }
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
