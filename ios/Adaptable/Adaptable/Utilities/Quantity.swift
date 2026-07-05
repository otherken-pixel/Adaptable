import Foundation

/// Parse and scale free-text ingredient quantities like "2 × 150 g (5 oz)",
/// "1 ½ cups", "½", "2.5 tbsp". Only the first numeric token is scaled;
/// text without numbers ("to taste", "a handful") passes through unchanged.
/// Mirrors `src/lib/quantity.ts`.
enum Quantity {
    private static let unicodeFractions: [String: Double] = [
        "¼": 0.25, "½": 0.5, "¾": 0.75,
        "⅓": 1.0 / 3.0, "⅔": 2.0 / 3.0,
        "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875,
    ]

    private static let niceFractions: [(Double, String)] = [
        (0, ""), (0.125, "⅛"), (0.25, "¼"), (1.0 / 3.0, "⅓"),
        (0.375, "⅜"), (0.5, "½"), (0.625, "⅝"), (2.0 / 3.0, "⅔"),
        (0.75, "¾"), (0.875, "⅞"), (1, ""),
    ]

    private static let numberRegex: NSRegularExpression = {
        // Leading numeric token: "1 ½", "1 1/2", "2.5", "2,5", "3/4", "½", "12"
        let pattern = #"(\d+(?:[.,]\d+)?\s+\d+\/\d+|\d+\s*[¼½¾⅓⅔⅛⅜⅝⅞]|\d+\/\d+|\d+(?:[.,]\d+)?|[¼½¾⅓⅔⅛⅜⅝⅞])"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    private static func parseNumeric(_ raw: String) -> Double? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if let v = unicodeFractions[s] { return v }

        if let m = match(#"^(\d+)\s*([¼½¾⅓⅔⅛⅜⅝⅞])$"#, in: s) {
            let whole = Double(m[0]) ?? 0
            let frac = unicodeFractions[m[1]] ?? 0
            return whole + frac
        }

        if let m = match(#"^(\d+(?:[.,]\d+)?)\s+(\d+)\/(\d+)$"#, in: s) {
            guard let denom = Double(m[2]), denom != 0 else { return nil }
            let whole = Double(m[0].replacingOccurrences(of: ",", with: ".")) ?? 0
            let num = Double(m[1]) ?? 0
            return whole + num / denom
        }

        if let m = match(#"^(\d+)\/(\d+)$"#, in: s) {
            guard let denom = Double(m[1]), denom != 0 else { return nil }
            return (Double(m[0]) ?? 0) / denom
        }

        let plain = s.replacingOccurrences(of: ",", with: ".")
        return Double(plain)
    }

    private static func match(_ pattern: String, in s: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(s.startIndex..., in: s)
        guard let m = re.firstMatch(in: s, range: range) else { return nil }
        var groups: [String] = []
        for i in 1..<m.numberOfRanges {
            guard let r = Range(m.range(at: i), in: s) else { return nil }
            groups.append(String(s[r]))
        }
        return groups
    }

    /// Render a number as a cook-friendly string ("1 ½", "¾", "2.3").
    static func formatNumber(_ value: Double) -> String {
        if value <= 0 { return "0" }
        let whole = floor(value + 1e-9)
        let frac = value - whole

        var best: (Double, String) = niceFractions[0]
        var bestDist = Double.infinity
        for candidate in niceFractions {
            let d = abs(frac - candidate.0)
            if d < bestDist {
                bestDist = d
                best = candidate
            }
        }

        if bestDist > 0.04 {
            let rounded = (value * 10).rounded() / 10
            if rounded == rounded.rounded() { return String(Int(rounded)) }
            return String(format: "%.1f", rounded)
        }

        var w = whole
        var f = best.1
        if best.0 == 1 {
            w += 1
            f = ""
        }
        if w == 0 { return f.isEmpty ? "0" : f }
        return f.isEmpty ? String(Int(w)) : "\(Int(w)) \(f)"
    }

    /// Scale the first number found in a quantity string by `factor`.
    static func scale(_ quantity: String, factor: Double) -> String {
        if abs(factor - 1) < 1e-9 { return quantity }
        let range = NSRange(quantity.startIndex..., in: quantity)
        guard let match = numberRegex.firstMatch(in: quantity, range: range),
              let matchRange = Range(match.range, in: quantity) else { return quantity }
        let token = String(quantity[matchRange])
        guard let value = parseNumeric(token) else { return quantity }
        let scaled = formatNumber(value * factor)
        return quantity.replacingCharacters(in: matchRange, with: scaled)
    }
}
