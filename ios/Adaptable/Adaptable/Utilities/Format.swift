import Foundation

/// Flexible ISO-8601 parsing for Postgres `timestamptz` strings, which may
/// or may not include fractional seconds.
enum ISODate {
    private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ iso: String) -> Date? {
        withFractional.date(from: iso) ?? plain.date(from: iso)
    }
}

enum Format {
    static func totalMinutes(prep: Int, cook: Int) -> String {
        let total = prep + cook
        if total >= 60 {
            let h = total / 60
            let m = total % 60
            return m != 0 ? "\(h) hr \(m) min" : "\(h) hr"
        }
        return "\(total) min"
    }

    static func timeAgo(_ iso: String) -> String {
        guard let date = ISODate.parse(iso) else { return "" }
        let seconds = max(1, Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(Int(minutes))m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(Int(hours))h ago" }
        let days = hours / 24
        if days < 7 { return "\(Int(days))d ago" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }

    /// Local-timezone yyyy-mm-dd. Never derive calendar dates from UTC
    /// components — that reads as "tomorrow" during US evenings.
    static func localISODate(_ date: Date = Date()) -> String {
        var cal = Calendar.current
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    static func compactCount(_ n: Int) -> String {
        if abs(n) >= 1000 {
            let scaled = Double(n) / 1000
            let rounded = (scaled * 10).rounded() / 10
            if rounded == rounded.rounded() {
                return "\(Int(rounded))k"
            }
            return String(format: "%.1fk", rounded)
        }
        return String(n)
    }
}
