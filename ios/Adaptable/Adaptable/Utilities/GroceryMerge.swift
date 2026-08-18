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
        if b.isEmpty || a.compare(b, options: .caseInsensitive) == .orderedSame { return a }
        return Quantity.add(a, b)
    }

    /// Canonical grocery key that collapses "leftover cooked chicken" → "chicken".
    static func batchKey(_ item: String) -> String {
        MealPrepBundles.normalizeIngredient(item)
    }
}
