import Foundation

/// Map grocery item names → store aisle. Mirrors `src/lib/aisle.ts`.
enum GroceryAisle {
    private static let rules: [(String, [String])] = [
        ("Produce", ["lettuce", "tomato", "onion", "garlic", "potato", "spinach", "herb", "cilantro", "basil", "lemon", "lime", "avocado", "pepper", "carrot", "celery", "mushroom", "apple", "berry", "fruit", "vegetable", "greens", "ginger", "cucumber", "zucchini", "broccoli", "kale", "parsley", "scallion", "shallot"]),
        ("Meat & Seafood", ["chicken", "beef", "pork", "turkey", "lamb", "sausage", "bacon", "salmon", "tuna", "shrimp", "fish", "steak", "ground"]),
        ("Dairy & Eggs", ["milk", "butter", "cheese", "yogurt", "yoghurt", "cream", "egg", "parmesan", "mozzarella", "feta", "cheddar"]),
        ("Bakery", ["bread", "bun", "tortilla", "pita", "bagel", "roll", "baguette"]),
        ("Pantry", ["rice", "pasta", "noodle", "flour", "sugar", "oil", "vinegar", "soy sauce", "broth", "stock", "bean", "lentil", "chickpea", "canned", "tomato paste", "spice", "salt", "pepper", "honey", "maple", "sauce", "mustard", "mayo", "ketchup"]),
        ("Frozen", ["frozen", "ice cream", "peas"]),
        ("Drinks", ["wine", "beer", "juice", "soda", "water", "coffee", "tea"]),
    ]

    static let order = [
        "Produce", "Meat & Seafood", "Dairy & Eggs", "Bakery", "Pantry", "Frozen", "Drinks", "Other",
    ]

    static func aisle(for itemName: String) -> String {
        let hay = itemName.lowercased()
        for (aisle, keys) in rules {
            if keys.contains(where: { hay.contains($0) }) { return aisle }
        }
        return "Other"
    }

    static func sortAisles(_ aisles: [String]) -> [String] {
        aisles.sorted {
            let ia = order.firstIndex(of: $0) ?? 99
            let ib = order.firstIndex(of: $1) ?? 99
            return ia < ib
        }
    }
}
