import Foundation

/// Ingredient overlap + cook-method compatibility for meal-prep bundles.
/// Keep in lockstep with `supabase/functions/_shared/mealPrep.ts`.
enum MealPrepBundles {
    enum CookingMethod: String {
        case oven, stovetop, sheetPan = "sheet_pan", airFryer = "air_fryer"
        case slowCooker = "slow_cooker", grill, noCook = "no_cook"
        case instantPot = "instant_pot", mixed

        var label: String {
            switch self {
            case .oven: return "Oven"
            case .stovetop: return "Stovetop"
            case .sheetPan: return "Sheet pan"
            case .airFryer: return "Air fryer"
            case .slowCooker: return "Slow cooker"
            case .grill: return "Grill"
            case .noCook: return "No-cook"
            case .instantPot: return "Instant Pot"
            case .mixed: return "Mixed"
            }
        }
    }

    enum MealSlot: String {
        case breakfast, lunch, dinner, snack, dessert, any
    }

    private static let staples: Set<String> = [
        "salt", "pepper", "oil", "olive oil", "vegetable oil", "sesame oil",
        "water", "butter", "sugar", "flour", "garlic", "onion", "shallot",
        "vinegar", "soy", "soy sauce", "tamari", "lemon", "lime", "chili",
        "cumin", "paprika", "oregano", "thyme", "ginger", "spray",
        "cooking spray", "black pepper", "kosher salt", "sea salt",
    ]

    static let batchable: Set<String> = [
        "chicken", "turkey", "beef", "pork", "tofu", "salmon", "shrimp", "tuna",
        "rice", "quinoa", "broccoli", "cauliflower", "sweet potato",
        "chickpea", "black bean", "lentil", "egg", "lamb",
    ]

    private static let fillers: Set<String> = [
        "boneless", "skinless", "fresh", "frozen", "large", "small", "medium",
        "diced", "chopped", "minced", "sliced", "cooked", "leftover", "leftovers",
        "shredded", "roasted", "canned", "drained", "dried", "ground", "whole",
        "baby", "extra", "firm", "can", "cloves", "fillet", "fillets",
        "breast", "breasts", "thigh", "thighs", "optional", "plus",
    ]

    private static let aliases: [String: String] = [
        "chickpeas": "chickpea", "garbanzo": "chickpea", "garbanzo beans": "chickpea",
        "black beans": "black bean", "green onion": "scallion", "green onions": "scallion",
        "spring onion": "scallion", "sweet potatoes": "sweet potato",
        "bell peppers": "bell pepper", "eggs": "egg",
        "sushi rice": "rice", "jasmine rice": "rice", "basmati rice": "rice",
        "brown rice": "rice", "broccolini": "broccoli", "broccoli florets": "broccoli",
    ]

    private static let collapse = [
        "chicken", "turkey", "beef", "pork", "lamb", "salmon", "tuna", "shrimp",
        "tofu", "broccoli", "cauliflower", "spinach", "kale", "rice", "quinoa",
        "chickpea", "lentil", "egg",
    ]

    private static let proteinFromKey: [String: String] = [
        "chicken": "chicken", "turkey": "turkey", "beef": "beef", "pork": "pork",
        "lamb": "lamb", "salmon": "fish", "tuna": "fish", "cod": "fish",
        "fish": "fish", "shrimp": "shrimp", "tofu": "tofu",
        "chickpea": "beans", "black bean": "beans", "lentil": "beans",
        "bean": "beans", "egg": "eggs",
    ]

    private static let complement: [CookingMethod: [CookingMethod]] = [
        .oven: [.stovetop, .noCook],
        .sheetPan: [.stovetop, .noCook],
        .stovetop: [.oven, .sheetPan, .airFryer, .slowCooker, .noCook],
        .airFryer: [.stovetop, .noCook],
        .slowCooker: [.stovetop, .noCook],
        .grill: [.stovetop, .noCook],
        .instantPot: [.stovetop, .noCook],
        .noCook: [.oven, .stovetop, .sheetPan],
        .mixed: [.noCook, .airFryer],
    ]

    private static let exclusive: Set<CookingMethod> = [.oven, .sheetPan, .airFryer, .grill]

    // MARK: - Normalize / infer

    static func normalizeIngredient(_ item: String) -> String {
        var s = item.lowercased()
        if let r = s.range(of: "(") { s = String(s[..<r.lowerBound]) }
        if let r = s.range(of: ",") { s = String(s[..<r.lowerBound]) }
        if let r = s.range(of: ";") { s = String(s[..<r.lowerBound]) }
        s = s.replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = s.split(separator: " ").map(String.init).filter { !$0.isEmpty && !fillers.contains($0) }
        s = parts.joined(separator: " ")
        if let aliased = aliases[s] { return aliased }
        for token in collapse where s == token || s.contains(token) { return token }
        if s.hasSuffix("oes"), s.count > 5 { return String(s.dropLast(2)) }
        if s.hasSuffix("s"), s.count > 4, !s.hasSuffix("ss") { return String(s.dropLast()) }
        return s
    }

    static func ingredientKeys(_ recipe: Recipe) -> [String] {
        if let stored = recipe.ingredient_keys, !stored.isEmpty { return stored }
        var keys = Set<String>()
        for ing in recipe.ingredients ?? [] {
            let key = normalizeIngredient(ing.item)
            if !key.isEmpty, !staples.contains(key) { keys.insert(key) }
        }
        return Array(keys)
    }

    static func cookingMethod(_ recipe: Recipe) -> CookingMethod {
        if let raw = recipe.primary_method, let stored = CookingMethod(rawValue: raw) {
            return stored
        }
        let tagHay = (recipe.tags ?? []).joined(separator: " ").lowercased()
        if tagHay.range(of: "sheet[\\-\\s]?pan", options: .regularExpression) != nil { return .sheetPan }
        if tagHay.range(of: "air[\\-\\s]?fry", options: .regularExpression) != nil { return .airFryer }
        if tagHay.range(of: "no[\\-\\s]?cook|overnight", options: .regularExpression) != nil { return .noCook }
        if tagHay.range(of: "slow[\\-\\s]?cook|crock", options: .regularExpression) != nil { return .slowCooker }
        if tagHay.range(of: "instant[\\-\\s]?pot|pressure", options: .regularExpression) != nil { return .instantPot }
        if tagHay.contains("grill") { return .grill }
        if tagHay.range(of: "one[\\-\\s]?pot|one[\\-\\s]?pan|stir[\\-\\s]?fry", options: .regularExpression) != nil {
            return .stovetop
        }

        let steps = (recipe.steps ?? [])
            .map { "\($0.instruction) \($0.tip ?? "")" }
            .joined(separator: " ")
            .lowercased()
        var hits = Set<CookingMethod>()
        if steps.range(of: "roast|bake|broil|oven", options: .regularExpression) != nil { hits.insert(.oven) }
        if steps.range(of: "sheet[\\-\\s]?pan", options: .regularExpression) != nil { hits.insert(.sheetPan) }
        if steps.range(of: "sauté|saute|sear|simmer|boil|stir[\\-\\s]?fry|pan[\\-\\s]?fry|wilt|skillet", options: .regularExpression) != nil {
            hits.insert(.stovetop)
        }
        if steps.range(of: "air[\\-\\s]?fry", options: .regularExpression) != nil { hits.insert(.airFryer) }
        if steps.contains("grill") { hits.insert(.grill) }
        if steps.range(of: "slow[\\-\\s]?cook|crock", options: .regularExpression) != nil { hits.insert(.slowCooker) }
        if steps.range(of: "instant[\\-\\s]?pot|pressure cook", options: .regularExpression) != nil { hits.insert(.instantPot) }
        if steps.range(of: "no heat|refrigerate|overnight|no cook", options: .regularExpression) != nil {
            hits.insert(.noCook)
        }

        if hits.contains(.sheetPan) { return .sheetPan }
        if hits.isEmpty {
            return (recipe.cook_time_minutes ?? 0) == 0 ? .noCook : .stovetop
        }
        if hits.count == 1 { return hits.first! }
        if hits.contains(.oven) && hits.contains(.stovetop) { return .mixed }
        if hits.contains(.oven) { return .oven }
        return hits.first!
    }

    static func mealSlot(_ recipe: Recipe) -> MealSlot {
        if let raw = recipe.meal_slot, let stored = MealSlot(rawValue: raw), stored != .any {
            return stored
        }
        let hay = "\(recipe.title ?? "") \(recipe.description ?? "") \((recipe.tags ?? []).joined(separator: " "))"
            .lowercased()
        if hay.range(of: "breakfast|brunch|overnight oat|morning", options: .regularExpression) != nil {
            return .breakfast
        }
        if hay.range(of: "dessert|brownie|cookie|cake|ice cream", options: .regularExpression) != nil {
            return .dessert
        }
        if hay.range(of: "snack|appetizer|dip", options: .regularExpression) != nil { return .snack }
        if hay.contains("lunch") { return .lunch }
        if hay.range(of: "dinner|weeknight|supper", options: .regularExpression) != nil { return .dinner }
        return .any
    }

    static func activePrepMinutes(_ recipe: Recipe) -> Int {
        if let stored = recipe.active_prep_minutes { return max(0, stored) }
        let prep = max(0, recipe.prep_time_minutes ?? 0)
        let cook = max(0, recipe.cook_time_minutes ?? 0)
        switch cookingMethod(recipe) {
        case .oven, .sheetPan, .airFryer, .slowCooker, .grill:
            return prep + Int((Double(cook) * 0.15).rounded())
        case .noCook:
            return prep
        case .mixed:
            return prep + Int((Double(cook) * 0.5).rounded())
        case .stovetop, .instantPot:
            return prep + Int((Double(cook) * 0.85).rounded())
        }
    }

    static func leftoverFocus(_ recipes: [Recipe]) -> [String] {
        var counts: [String: Int] = [:]
        for r in recipes {
            for k in ingredientKeys(r) where batchable.contains(k) {
                counts[k, default: 0] += 1
            }
        }
        return counts.keys.sorted {
            if counts[$0, default: 0] != counts[$1, default: 0] {
                return counts[$0, default: 0] > counts[$1, default: 0]
            }
            return $0 < $1
        }
    }

    // MARK: - Scoring

    struct Overlap {
        let score: Double
        let shared: [String]
        let batchableShared: [String]
    }

    static func overlap(_ a: Recipe, _ b: Recipe) -> Overlap {
        let ka = Set(ingredientKeys(a))
        let kb = Set(ingredientKeys(b))
        let shared = ka.intersection(kb)
        let batch = shared.filter { batchable.contains($0) }
        var num = 0.0
        var den = 0.0
        for k in ka.union(kb) {
            let w = batchable.contains(k) ? 3.0 : 1.0
            den += w
            if shared.contains(k) { num += w }
        }
        return Overlap(
            score: den == 0 ? 0 : num / den,
            shared: shared.sorted(),
            batchableShared: batch.sorted()
        )
    }

    static func methodsCompatible(_ a: Recipe, _ b: Recipe) -> Bool {
        let ma = cookingMethod(a)
        let mb = cookingMethod(b)
        if ma == mb { return !exclusive.contains(ma) }
        let options = complement[ma] ?? []
        return options.contains(mb)
    }

    static func sessionMinutes(_ recipes: [Recipe]) -> (active: Int, parallel: Int) {
        let active = recipes.reduce(0) { $0 + activePrepMinutes($1) }
        let maxTotal = recipes.map(\.totalMinutes).max() ?? 0
        return (active, max(active, maxTotal))
    }

    static func passesPreferences(_ recipe: Recipe, prefs: Preferences) -> Bool {
        let hay = (
            [recipe.title ?? "", recipe.description ?? ""]
                + (recipe.ingredients ?? []).map { "\($0.item) \($0.note ?? "")" }
                + (recipe.steps ?? []).map(\.instruction)
        )
        .joined(separator: " ")
        .lowercased()

        for allergy in prefs.allergies ?? [] {
            if allergyTerms(allergy).contains(where: { $0.count >= 3 && hay.contains($0) }) {
                return false
            }
        }
        for dislike in prefs.dislikes ?? [] {
            let key = dislike.lowercased().trimmingCharacters(in: .whitespaces)
            if key.count >= 3, hay.contains(key) { return false }
        }

        let diets = (prefs.diets ?? []).map { $0.lowercased() }
        let protein = recipe.base_protein ?? proteinFromKey[ingredientKeys(recipe).first { proteinFromKey[$0] != nil } ?? ""] ?? "none"
        let meat: Set<String> = ["chicken", "beef", "pork", "turkey", "lamb"]
        let animal: Set<String> = meat.union(["fish", "shrimp", "eggs"])
        if diets.contains(where: { $0.contains("vegan") }) {
            if animal.contains(protein) { return false }
            if ["cheese", "milk", "yogurt", "yoghurt", "honey", "butter", "cream"].contains(where: { hay.contains($0) }) {
                return false
            }
        } else if diets.contains(where: { $0.contains("vegetarian") }) {
            if meat.contains(protein) || protein == "fish" || protein == "shrimp" { return false }
        } else if diets.contains(where: { $0.contains("pescatarian") }) {
            if meat.contains(protein) { return false }
        }
        return true
    }

    private static func allergyTerms(_ label: String) -> [String] {
        switch label.lowercased() {
        case "peanut", "peanuts": return ["peanut", "peanuts", "groundnut"]
        case "dairy", "milk": return ["milk", "butter", "cheese", "cream", "yogurt", "yoghurt", "whey"]
        case "egg", "eggs": return ["egg", "eggs", "mayonnaise"]
        case "gluten", "wheat": return ["wheat", "barley", "rye", "flour", "breadcrumbs", "pasta"]
        case "shellfish": return ["shrimp", "prawn", "crab", "lobster", "scallop", "clam", "mussel"]
        case "fish": return ["fish", "salmon", "tuna", "cod", "anchovy", "sardine"]
        case "soy": return ["soy", "soya", "tofu", "tempeh", "edamame", "miso"]
        case "sesame": return ["sesame", "tahini"]
        case "tree nuts", "tree nut": return ["almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut"]
        default: return [label.lowercased()]
        }
    }

    // MARK: - Assemble / select

    static func assemble(
        kind: BundleKind,
        recipes: [Recipe],
        generatedIds: [String] = [],
        missingCount: Int = 0
    ) -> MealPrepBundle {
        let times = sessionMinutes(recipes)
        let focus = leftoverFocus(recipes)
        let methods = recipes.map { cookingMethod($0) }
        let cals = recipes.compactMap(\.calories)
        let avg = cals.isEmpty ? nil : cals.reduce(0, +) / cals.count
        let headline: String
        let reason: String
        if kind == .concurrent {
            let a = methods.first?.label ?? "Cook"
            let b = (methods.dropFirst().first ?? methods.first)?.label ?? "together"
            headline = "\(a) + \(b) · Prep in \(times.parallel) min"
            reason = "These cook at the same time without fighting for the same burner or oven."
        } else {
            let shared = focus.prefix(2).map { $0 }
            headline = "Shared base: \(Format.list(Array(shared)))"
            reason = missingCount > 0
                ? "Batch-cook \(Format.list(Array(shared))) — generate the missing meal to finish the week."
                : "Batch-cook \(Format.list(Array(shared))) once, then eat it \(recipes.count) ways."
        }
        return MealPrepBundle(
            id: recipes.map(\.id).sorted().joined(separator: "+"),
            kind: kind,
            recipes: recipes,
            headline: headline,
            reason: reason,
            shared_ingredients: Array(focus.prefix(3)),
            session_minutes: times.parallel,
            active_minutes: times.active,
            avg_calories: avg,
            generated_ids: generatedIds,
            missing_count: missingCount,
            leftover_focus: Array(focus.prefix(3))
        )
    }

    /// Rank existing recipes into 3–5 bundles. Incomplete seeds (missing 1–2
    /// meals) are included so the UI can offer generate-to-complete.
    static func select(pool: [Recipe], prefs: Preferences, limit: Int = 5) -> [MealPrepBundle] {
        let eligible = pool.filter { passesPreferences($0, prefs: prefs) }
        guard eligible.count >= 1 else { return [] }

        var complete: [MealPrepBundle] = []
        var seen = Set<String>()

        // Shared-base: cluster on batchable keys.
        var inverted: [String: [Recipe]] = [:]
        for r in eligible {
            for k in ingredientKeys(r) where batchable.contains(k) {
                inverted[k, default: []].append(r)
            }
        }

        for (key, group) in inverted where group.count >= 2 {
            let ranked = group.sorted { ($0.cook_count ?? 0) > ($1.cook_count ?? 0) }
            let top = Array(ranked.prefix(8))
            if top.count >= 3 {
                if let triple = bestTriple(top, requiredKey: key) {
                    let id = triple.map(\.id).sorted().joined(separator: "+")
                    if seen.insert(id).inserted {
                        complete.append(assemble(kind: .sharedBase, recipes: triple))
                    }
                }
            }
            if let pair = bestPair(top, requiredKey: key) {
                let id = pair.map(\.id).sorted().joined(separator: "+")
                if seen.insert(id).inserted {
                    complete.append(assemble(kind: .sharedBase, recipes: pair))
                }
            }
        }

        // Concurrent: complementary methods.
        var byMethod: [CookingMethod: [Recipe]] = [:]
        for r in eligible { byMethod[cookingMethod(r), default: []].append(r) }
        for (method, groupA) in byMethod {
            for other in complement[method] ?? [] {
                guard let groupB = byMethod[other], !groupB.isEmpty else { continue }
                let a = groupA.sorted { ($0.cook_count ?? 0) > ($1.cook_count ?? 0) }.prefix(4)
                let b = groupB.sorted { ($0.cook_count ?? 0) > ($1.cook_count ?? 0) }.prefix(4)
                outer: for ra in a {
                    for rb in b where ra.id != rb.id && methodsCompatible(ra, rb) {
                        if diversityPenalty(ra, rb) > 0.7 { continue }
                        let recipes = [ra, rb]
                        let id = recipes.map(\.id).sorted().joined(separator: "+")
                        if seen.insert(id).inserted {
                            complete.append(assemble(kind: .concurrent, recipes: recipes))
                        }
                        break outer
                    }
                }
            }
        }

        complete.sort { score($0) > score($1) }

        var out: [MealPrepBundle] = []
        var usedRecipes = Set<String>()
        for bundle in complete {
            if out.count >= limit { break }
            let overlapCount = bundle.recipes.filter { usedRecipes.contains($0.id) }.count
            if overlapCount >= bundle.recipes.count { continue }
            out.append(bundle)
            bundle.recipes.forEach { usedRecipes.insert($0.id) }
        }

        // Incomplete seeds for generate-to-complete.
        if out.count < limit {
            let leftovers = leftoverFocus(eligible)
            for key in leftovers {
                if out.count >= limit { break }
                let unused = (inverted[key] ?? []).filter { !usedRecipes.contains($0.id) }
                guard let seed = unused.max(by: { ($0.cook_count ?? 0) < ($1.cook_count ?? 0) }) else { continue }
                var recipes = [seed]
                if unused.count >= 2 {
                    if let second = unused.first(where: { $0.id != seed.id && diversityPenalty(seed, $0) < 0.7 }) {
                        recipes.append(second)
                    }
                }
                usedRecipes.formUnion(recipes.map(\.id))
                out.append(assemble(
                    kind: .sharedBase,
                    recipes: recipes,
                    missingCount: max(1, 3 - recipes.count)
                ))
            }
        }

        return Array(out.prefix(limit))
    }

    private static func score(_ bundle: MealPrepBundle) -> Double {
        var s = 0.0
        if bundle.kind == .sharedBase {
            s += Double(bundle.shared_ingredients.filter { batchable.contains($0) }.count) * 2
            s += bundle.missing_count == 0 ? 3 : 0.5
        } else {
            s += 2
            s += bundle.session_minutes <= 60 ? 1 : 0
        }
        s += Double(bundle.recipes.count) * 0.4
        return s
    }

    private static func bestPair(_ recipes: [Recipe], requiredKey: String) -> [Recipe]? {
        var best: [Recipe]?
        var bestScore = 0.25
        for i in 0..<recipes.count {
            for j in (i + 1)..<recipes.count {
                let ov = overlap(recipes[i], recipes[j])
                guard ov.batchableShared.contains(requiredKey) else { continue }
                if diversityPenalty(recipes[i], recipes[j]) > 0.75 { continue }
                if ov.score > bestScore {
                    bestScore = ov.score
                    best = [recipes[i], recipes[j]]
                }
            }
        }
        return best
    }

    private static func bestTriple(_ recipes: [Recipe], requiredKey: String) -> [Recipe]? {
        guard recipes.count >= 3 else { return nil }
        var best: [Recipe]?
        var bestScore = 0.2
        for i in 0..<recipes.count {
            for j in (i + 1)..<recipes.count {
                for k in (j + 1)..<recipes.count {
                    let trio = [recipes[i], recipes[j], recipes[k]]
                    let ab = overlap(trio[0], trio[1])
                    let ac = overlap(trio[0], trio[2])
                    let bc = overlap(trio[1], trio[2])
                    let batch = Set(ab.batchableShared + ac.batchableShared + bc.batchableShared)
                    guard batch.contains(requiredKey) else { continue }
                    if diversityPenalty(trio[0], trio[1]) > 0.75 { continue }
                    if diversityPenalty(trio[0], trio[2]) > 0.75 { continue }
                    let avg = (ab.score + ac.score + bc.score) / 3
                    if avg > bestScore {
                        bestScore = avg
                        best = trio
                    }
                }
            }
        }
        return best
    }

    /// 0 = distinct, 1 = near-duplicate.
    private static func diversityPenalty(_ a: Recipe, _ b: Recipe) -> Double {
        let ta = tokens(a.title ?? "")
        let tb = tokens(b.title ?? "")
        guard !ta.isEmpty, !tb.isEmpty else { return 0 }
        let inter = Double(ta.intersection(tb).count)
        let union = Double(ta.union(tb).count)
        return union == 0 ? 0 : inter / union
    }

    private static func tokens(_ title: String) -> Set<String> {
        let stop: Set<String> = ["the", "and", "with", "a", "in", "of"]
        return Set(
            title.lowercased()
                .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
                .split(separator: " ")
                .map(String.init)
                .filter { $0.count > 2 && !stop.contains($0) }
        )
    }
}
