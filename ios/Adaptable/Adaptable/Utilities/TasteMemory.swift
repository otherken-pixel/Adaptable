import Foundation

/// Quiet taste updates from cooks, remixes, pantry picks and leftover accepts.
/// Allergies stay a hard server rule — this only drifts likes.
enum TasteMemory {
    static func recordCook(_ recipe: Recipe, prefs: Preferences) -> Preferences {
        bump(prefs, cuisine: recipe.cuisine, protein: recipe.base_protein ?? protein(from: recipe), staple: nil, spice: 0)
    }

    static func recordVote(_ recipe: Recipe, value: Int, prefs: Preferences) -> Preferences {
        let delta = value >= 0 ? 1 : -1
        return bump(prefs, cuisine: recipe.cuisine, protein: recipe.base_protein ?? protein(from: recipe), staple: nil, spice: 0, amount: delta)
    }

    static func recordRemix(prompt: String, prefs: Preferences) -> Preferences {
        let lower = prompt.lowercased()
        var delta = 0
        if lower.contains("spicy") || lower.contains("hotter") { delta = 1 }
        if lower.contains("mild") || lower.contains("less spice") { delta = -1 }
        return bump(prefs, cuisine: nil, protein: nil, staple: nil, spice: delta)
    }

    static func recordPantry(_ items: [String], prefs: Preferences) -> Preferences {
        var next = prefs
        var learned = next.learned ?? LearnedTaste()
        var staples = learned.staples
        for item in items {
            let key = MealPrepBundles.normalizeIngredient(item)
            guard key.count >= 3, !staples.contains(key) else { continue }
            staples.append(key)
        }
        learned.staples = Array(staples.prefix(24))
        next.learned = learned
        return next
    }

    static func recordLeftover(focus: [String], prefs: Preferences) -> Preferences {
        var next = prefs
        var learned = next.learned ?? LearnedTaste()
        for key in focus {
            learned.proteins[key, default: 0] += 2
        }
        next.learned = learned
        return next
    }

    static func rank(_ recipes: [Recipe], prefs: Preferences) -> [Recipe] {
        let learned = prefs.learned ?? LearnedTaste()
        let goals = Nutrition.goals(from: prefs)
        guard !learned.cuisines.isEmpty || !learned.proteins.isEmpty || goals.hasAny else { return recipes }
        return recipes.sorted { a, b in
            score(a, learned: learned, goals: goals) > score(b, learned: learned, goals: goals)
        }
    }

    static func score(_ recipe: Recipe, learned: LearnedTaste, goals: Nutrition.Goals = Nutrition.Goals(calorie_target: nil, protein_target_g: nil, carbs_target_g: nil, fat_target_g: nil, meals_per_day: 3)) -> Int {
        var n = 0
        if let c = recipe.cuisine { n += learned.cuisines[c] ?? 0 }
        let protein = recipe.base_protein ?? protein(from: recipe)
        if let protein { n += (learned.proteins[protein] ?? 0) * 2 }
        n += Nutrition.goalScore(recipe, goals: goals)
        return n
    }

    private static func protein(from recipe: Recipe) -> String? {
        MealPrepBundles.leftoverFocus([recipe]).first
    }

    private static func bump(
        _ prefs: Preferences,
        cuisine: String?,
        protein: String?,
        staple: String?,
        spice: Int,
        amount: Int = 1
    ) -> Preferences {
        var next = prefs
        var learned = next.learned ?? LearnedTaste()
        if let cuisine, !cuisine.isEmpty {
            learned.cuisines[cuisine, default: 0] += amount
        }
        if let protein, !protein.isEmpty, protein != "none" {
            learned.proteins[protein, default: 0] += amount
        }
        if let staple, !staple.isEmpty, !learned.staples.contains(staple) {
            learned.staples.append(staple)
        }
        learned.spice_delta = max(-3, min(3, learned.spice_delta + spice))
        if learned.spice_delta >= 2 { next.spice = "Hot" }
        if learned.spice_delta <= -2 { next.spice = "Mild" }
        next.learned = learned
        return next
    }
}
