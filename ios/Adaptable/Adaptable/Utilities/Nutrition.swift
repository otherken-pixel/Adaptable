import Foundation

/// Daily calorie / macro goals and per-plate planner math.
/// Mirrors `supabase/functions/_shared/nutrition.ts` / `src/lib/nutrition.ts`.
///
/// Counting rule: one planned meal contributes eat_servings × per-serving
/// macros (default eat_servings = 1). Cook yield is ignored.
enum Nutrition {
    static let caloriePresets = [1600, 2000, 2400]
    static let proteinPresets = [100, 130, 160]
    static let defaultMealsPerDay = 3
    static let minMealsPerDay = 1
    static let maxMealsPerDay = 6
    static let minCalorieTarget = 800
    static let maxCalorieTarget = 5000
    static let minMacroG = 10
    static let maxMacroG = 400
    static let minEatServings = 1
    static let maxEatServings = 8
    static let goalSlack = 0.15
    static let calorieLocks = [400, 500, 650]
    static let proteinLocks = [30, 40]
    static let fillMinCalories = 150
    static let fillMinProtein = 10
    static let generatePromptMax = 500

    struct Goals: Equatable {
        var calorie_target: Int?
        var protein_target_g: Int?
        var carbs_target_g: Int?
        var fat_target_g: Int?
        var meals_per_day: Int

        var hasAny: Bool {
            calorie_target != nil || protein_target_g != nil || carbs_target_g != nil || fat_target_g != nil
        }

        var summary: String {
            var bits: [String] = []
            if let calorie_target { bits.append("\(calorie_target) cal") }
            if let protein_target_g { bits.append("\(protein_target_g)g P") }
            if let carbs_target_g { bits.append("\(carbs_target_g)g C") }
            if let fat_target_g { bits.append("\(fat_target_g)g F") }
            return bits.joined(separator: " · ")
        }
    }

    struct Macros: Equatable {
        var calories: Int?
        var protein_g: Int?
        var carbs_g: Int?
        var fat_g: Int?
    }

    struct Day: Equatable {
        var totals: Macros
        var unknownMeals: Int
        var mealCount: Int
    }

    static func clampCalorieTarget(_ value: Int?) -> Int? {
        clamp(value, min: minCalorieTarget, max: maxCalorieTarget)
    }

    static func clampMacroGrams(_ value: Int?) -> Int? {
        clamp(value, min: minMacroG, max: maxMacroG)
    }

    static func clampMealsPerDay(_ value: Int?) -> Int {
        clamp(value, min: minMealsPerDay, max: maxMealsPerDay) ?? defaultMealsPerDay
    }

    static func clampEatServings(_ value: Int?) -> Int {
        clamp(value, min: minEatServings, max: maxEatServings) ?? 1
    }

    static func goals(from prefs: Preferences?) -> Goals {
        Goals(
            calorie_target: clampCalorieTarget(prefs?.calorie_target),
            protein_target_g: clampMacroGrams(prefs?.protein_target_g),
            carbs_target_g: clampMacroGrams(prefs?.carbs_target_g),
            fat_target_g: clampMacroGrams(prefs?.fat_target_g),
            meals_per_day: clampMealsPerDay(prefs?.meals_per_day)
        )
    }

    static func perMealBudget(_ goals: Goals) -> Macros {
        let n = max(1, goals.meals_per_day)
        func split(_ daily: Int?) -> Int? {
            guard let daily else { return nil }
            return Int((Double(daily) / Double(n)).rounded())
        }
        return Macros(
            calories: split(goals.calorie_target),
            protein_g: split(goals.protein_target_g),
            carbs_g: split(goals.carbs_target_g),
            fat_g: split(goals.fat_target_g)
        )
    }

    static func plateMacros(_ recipe: Recipe?, eatServings: Int?) -> Macros {
        let plates = clampEatServings(eatServings)
        func scale(_ value: Int?) -> Int? {
            guard let value else { return nil }
            return Int((Double(value) * Double(plates)).rounded())
        }
        return Macros(
            calories: scale(recipe?.calories),
            protein_g: scale(recipe?.protein_g),
            carbs_g: scale(recipe?.carbs_g),
            fat_g: scale(recipe?.fat_g)
        )
    }

    static func sumDay(_ entries: [MealPlanEntry]) -> Day {
        var totals = Macros()
        var unknown = 0
        for entry in entries {
            let plate = plateMacros(entry.recipe, eatServings: entry.eat_servings)
            if plate.calories == nil && plate.protein_g == nil && plate.carbs_g == nil && plate.fat_g == nil {
                unknown += 1
                continue
            }
            totals.calories = add(totals.calories, plate.calories)
            totals.protein_g = add(totals.protein_g, plate.protein_g)
            totals.carbs_g = add(totals.carbs_g, plate.carbs_g)
            totals.fat_g = add(totals.fat_g, plate.fat_g)
        }
        return Day(totals: totals, unknownMeals: unknown, mealCount: entries.count)
    }

    static func remaining(_ goals: Goals, totals: Macros) -> Macros {
        Macros(
            calories: leftover(goals.calorie_target, totals.calories),
            protein_g: leftover(goals.protein_target_g, totals.protein_g),
            carbs_g: leftover(goals.carbs_target_g, totals.carbs_g),
            fat_g: leftover(goals.fat_target_g, totals.fat_g)
        )
    }

    static func recipeFits(_ recipe: Recipe, goals: Goals, slack: Double = goalSlack) -> Bool {
        guard goals.hasAny else { return false }
        let budget = perMealBudget(goals)
        if let cap = budget.calories {
            guard let calories = recipe.calories else { return false }
            if calories > Int((Double(cap) * (1 + slack)).rounded()) { return false }
        }
        if let floor = budget.protein_g {
            guard let protein = recipe.protein_g else { return false }
            if protein < Int((Double(floor) * (1 - slack)).rounded()) { return false }
        }
        if let target = budget.carbs_g {
            guard let carbs = recipe.carbs_g else { return false }
            let lo = Int((Double(target) * (1 - slack)).rounded())
            let hi = Int((Double(target) * (1 + slack)).rounded())
            if carbs < lo || carbs > hi { return false }
        }
        if let target = budget.fat_g {
            guard let fat = recipe.fat_g else { return false }
            let lo = Int((Double(target) * (1 - slack)).rounded())
            let hi = Int((Double(target) * (1 + slack)).rounded())
            if fat < lo || fat > hi { return false }
        }
        return true
    }

    static func goalScore(_ recipe: Recipe, goals: Goals) -> Int {
        goals.hasAny && recipeFits(recipe, goals: goals) ? 3 : 0
    }

    static func lockConstraintPrompt(maxCalories: Int?, minProtein: Int?) -> String {
        var parts: [String] = []
        if let maxCalories, maxCalories > 0 {
            parts.append("Keep this at or under \(maxCalories) calories per serving.")
        }
        if let minProtein, minProtein > 0 {
            parts.append("Include at least \(minProtein) g protein per serving.")
        }
        return parts.isEmpty ? "" : parts.joined(separator: " ") + " "
    }

    /// Reserve lock sentences inside the generate-recipe prompt cap.
    static func applyLockConstraintPrompt(_ basePrompt: String, maxCalories: Int?, minProtein: Int?, limit: Int = generatePromptMax) -> String {
        let lock = lockConstraintPrompt(maxCalories: maxCalories, minProtein: minProtein)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = basePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if lock.isEmpty { return String(base.prefix(limit)) }
        let room = max(0, limit - lock.count - 1)
        let head = String(base.prefix(room)).trimmingCharacters(in: .whitespacesAndNewlines)
        if head.isEmpty { return String(lock.prefix(limit)) }
        return String("\(head) \(lock)".prefix(limit))
    }

    static func suggestedFillSlot(now: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        if hour < 11 { return "breakfast" }
        if hour < 15 { return "lunch" }
        return "dinner"
    }

    static func fillTodayPrompt(remaining: Macros, slot: String?) -> String {
        let resolved = (slot?.isEmpty == false) ? slot! : suggestedFillSlot()
        var bits = ["A complete \(resolved) that finishes today's plan"]
        if let calories = remaining.calories {
            if calories >= fillMinCalories {
                bits.append("around \(calories) calories")
            } else if calories < 0 {
                bits.append("as light as possible on calories")
            }
        }
        if let protein = remaining.protein_g, protein >= fillMinProtein {
            bits.append("at least \(protein) g protein")
        }
        return bits.joined(separator: ", ") + "."
    }

    static func formatPlateMeta(_ recipe: Recipe?, eatServings: Int = 1) -> String {
        let plate = plateMacros(recipe, eatServings: eatServings)
        var bits: [String] = []
        if let calories = plate.calories { bits.append("\(calories) cal") }
        if let protein = plate.protein_g { bits.append("\(protein)g P") }
        return bits.joined(separator: " · ")
    }

    static func fitLine(recipe: Recipe, goals: Goals) -> String? {
        guard goals.hasAny else { return nil }
        let budget = perMealBudget(goals)
        guard let calories = recipe.calories else {
            return "No calorie estimate — check the ingredients if you are tracking today."
        }
        if let cap = budget.calories {
            let delta = calories - cap
            if abs(delta) <= Int((Double(cap) * goalSlack).rounded()) {
                return "Fits your ~\(cap) cal per-meal budget."
            }
            if delta > 0 {
                return "About \(delta) cal over your ~\(cap) cal per-meal target."
            }
            return "About \(abs(delta)) cal under your ~\(cap) cal per-meal target."
        }
        if let floor = budget.protein_g {
            guard let protein = recipe.protein_g else { return "No protein estimate for this plate." }
            if protein >= floor { return "Hits your ~\(floor) g protein per-meal target." }
            return "About \(floor - protein) g short of your ~\(floor) g protein target."
        }
        return nil
    }

    static func shouldOfferFillToday(goals: Goals, remaining: Macros, isToday: Bool = true) -> Bool {
        guard isToday, goals.hasAny else { return false }
        if let calories = remaining.calories, calories >= fillMinCalories { return true }
        if let protein = remaining.protein_g, protein >= fillMinProtein { return true }
        if let calories = remaining.calories, calories < 0 { return true }
        return false
    }

    static func fillLocks(from remaining: Macros) -> (maxCalories: Int?, minProtein: Int?) {
        let maxCalories: Int?
        if let calories = remaining.calories, calories > 0 {
            maxCalories = max(fillMinCalories, calories)
        } else if let calories = remaining.calories, calories < 0 {
            maxCalories = calorieLocks[0]
        } else {
            maxCalories = nil
        }
        let minProtein: Int?
        if let protein = remaining.protein_g, protein >= fillMinProtein {
            minProtein = protein
        } else {
            minProtein = nil
        }
        return (maxCalories, minProtein)
    }

    private static func clamp(_ value: Int?, min: Int, max: Int) -> Int? {
        guard let value else { return nil }
        if value < min || value > max { return nil }
        return value
    }

    private static func add(_ a: Int?, _ b: Int?) -> Int? {
        if a == nil && b == nil { return nil }
        return (a ?? 0) + (b ?? 0)
    }

    private static func leftover(_ daily: Int?, _ used: Int?) -> Int? {
        guard let daily else { return nil }
        return daily - (used ?? 0)
    }
}
