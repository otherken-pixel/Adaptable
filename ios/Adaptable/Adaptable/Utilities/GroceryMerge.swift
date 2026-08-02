import Foundation

enum GroceryMerge {
    static func normalizeKey(_ item: String) -> String {
        item.lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func mergeQuantities(existing: String, incoming: String) -> String {
        let a = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty { return b }
        if b.isEmpty || a == b { return a }
        if a.lowercased().contains(b.lowercased()) { return a }
        return "\(a) + \(b)"
    }
}
