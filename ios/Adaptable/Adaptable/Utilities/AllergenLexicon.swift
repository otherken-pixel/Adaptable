import Foundation

/// Shared allergen lexicon + token-aware matcher.
/// Keep in lockstep with `supabase/functions/_shared/allergenLexicon.ts`
/// (same keys, terms, exceptions, and token-window rules).
enum AllergenLexicon {
    static let chips = [
        "Peanuts", "Tree nuts", "Shellfish", "Fish", "Eggs",
        "Dairy", "Gluten", "Soy", "Sesame", "Mustard",
    ]

    private struct Rule {
        let terms: [String]
        let exceptions: [String]
    }

    private static let dairyExceptions = [
        "coconut cream", "cream of tartar", "coconut milk", "almond milk",
        "oat milk", "soy milk", "soya milk", "rice milk", "cashew milk",
        "hemp milk", "pea milk", "flax milk", "macadamia milk",
        "peanut butter", "almond butter", "cashew butter", "sunflower butter",
        "cookie butter", "cocoa butter", "shea butter", "nut butter",
    ]

    private static let flourExceptions = [
        "rice flour", "almond flour", "coconut flour", "chickpea flour",
        "garbanzo flour", "tapioca flour", "potato flour", "corn flour",
        "oat flour", "buckwheat flour", "sorghum flour", "millet flour",
        "teff flour",
    ]

    private static let rules: [String: Rule] = [
        "peanut": Rule(
            terms: ["peanut", "peanuts", "groundnut", "groundnuts", "ground nut", "arachis"],
            exceptions: []
        ),
        "tree nut": Rule(
            terms: [
                "almond", "almonds", "cashew", "cashews", "walnut", "walnuts",
                "pecan", "pecans", "pistachio", "pistachios", "hazelnut", "hazelnuts",
                "macadamia", "macadamias", "brazil nut", "brazil nuts", "pine nut",
                "pine nuts", "tree nut", "tree nuts", "nutella", "marzipan",
            ],
            exceptions: []
        ),
        "dairy": Rule(
            terms: [
                "milk", "butter", "cheese", "cream", "yogurt", "yoghurt", "whey",
                "casein", "lactose", "ghee", "paneer", "mozzarella", "cheddar",
                "parmesan", "parmigiano", "feta", "ricotta", "brie", "gouda",
                "gruyere", "halloumi", "mascarpone", "cottage cheese", "sour cream",
                "creme fraiche", "half and half", "buttermilk", "ice cream",
            ],
            exceptions: dairyExceptions
        ),
        "egg": Rule(
            terms: ["egg", "eggs", "mayonnaise", "aioli", "meringue"],
            exceptions: []
        ),
        "gluten": Rule(
            terms: [
                "wheat", "barley", "rye", "malt", "seitan", "flour", "breadcrumbs",
                "bread crumbs", "soy sauce", "pasta", "couscous", "farro", "spelt",
            ],
            exceptions: flourExceptions
        ),
        "wheat": Rule(
            terms: ["wheat", "flour", "breadcrumbs", "bread crumbs", "seitan", "bulgur"],
            exceptions: flourExceptions
        ),
        "shellfish": Rule(
            terms: [
                "shrimp", "prawn", "prawns", "crab", "lobster", "crawfish", "crayfish",
                "scallop", "scallops", "clam", "clams", "mussel", "mussels", "oyster",
                "oysters", "shellfish", "calamari", "squid", "oyster sauce",
            ],
            exceptions: []
        ),
        "fish": Rule(
            terms: [
                "fish", "salmon", "tuna", "cod", "anchovy", "anchovies", "sardine",
                "sardines", "trout", "bass", "halibut", "tilapia", "fish sauce",
                "worcestershire", "nam pla", "nuoc mam", "dashi", "bonito",
                "katsuobushi",
            ],
            exceptions: []
        ),
        "soy": Rule(
            terms: ["soy", "soya", "tofu", "tempeh", "edamame", "miso", "soy sauce", "tamari"],
            exceptions: []
        ),
        "sesame": Rule(
            terms: ["sesame", "tahini", "benne", "hummus"],
            exceptions: []
        ),
        "mustard": Rule(
            terms: [
                "mustard", "dijon", "mustard seed", "mustard seeds", "mustard powder",
                "english mustard", "yellow mustard", "brown mustard",
            ],
            exceptions: []
        ),
    ]

    private static let labelToCanonical: [String: String] = [
        "peanut": "peanut", "peanuts": "peanut",
        "tree nut": "tree nut", "tree nuts": "tree nut",
        "dairy": "dairy", "milk": "dairy",
        "egg": "egg", "eggs": "egg",
        "gluten": "gluten", "wheat": "wheat",
        "shellfish": "shellfish", "fish": "fish",
        "soy": "soy", "sesame": "sesame", "mustard": "mustard",
    ]

    static func canonicalKey(_ label: String) -> String {
        let key = label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[-_]+", with: " ", options: .regularExpression)
        if let mapped = labelToCanonical[key] { return mapped }
        let bare = key.hasSuffix("s") ? String(key.dropLast()) : key
        return labelToCanonical[bare] ?? key
    }

    static func terms(for label: String) -> [String] {
        rulesFor(label).flatMap(\.terms)
    }

    /// Full-recipe scan (title, description, ingredients, steps). Discover For you.
    static func violations(in recipe: Recipe, allergies: [String]) -> [String] {
        hits(hay: hayTokens(recipe, ingredientsOnly: false), allergies: allergies)
    }

    /// Ingredient item + note only. Cook Mode hard-block.
    static func ingredientViolations(in recipe: Recipe, allergies: [String]) -> [String] {
        hits(hay: hayTokens(recipe, ingredientsOnly: true), allergies: allergies)
    }

    static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "['’]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    // MARK: - Internals

    private static func rulesFor(_ label: String) -> [Rule] {
        let key = canonicalKey(label)
        if key == "nut" || key == "nuts" {
            return [rules["peanut"], rules["tree nut"]].compactMap { $0 }
        }
        if let rule = rules[key] { return [rule] }
        let custom = label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? [] : [Rule(terms: [custom], exceptions: [])]
    }

    private static func hayTokens(_ recipe: Recipe, ingredientsOnly: Bool) -> [String] {
        var chunks: [String] = []
        if !ingredientsOnly {
            chunks.append(recipe.title ?? "")
            chunks.append(recipe.description ?? "")
        }
        for ing in recipe.ingredients ?? [] {
            chunks.append("\(ing.item) \(ing.note ?? "")")
        }
        if !ingredientsOnly {
            for step in recipe.steps ?? [] {
                chunks.append("\(step.instruction) \(step.tip ?? "")")
            }
        }
        return tokenize(chunks.joined(separator: " "))
    }

    private static func hits(hay: [String], allergies: [String]) -> [String] {
        guard !allergies.isEmpty, !hay.isEmpty else { return [] }
        var found: [String] = []
        var seen = Set<String>()
        for allergy in allergies {
            let matched = rulesFor(allergy).contains { rule in
                rule.terms.contains { contains(hay: hay, term: $0, exceptions: rule.exceptions) }
            }
            if matched, seen.insert(allergy).inserted {
                found.append(allergy)
            }
        }
        return found
    }

    private static func contains(hay: [String], term: String, exceptions: [String]) -> Bool {
        let termTokens = tokenize(term)
        guard !termTokens.isEmpty, hay.count >= termTokens.count else { return false }
        for i in 0...(hay.count - termTokens.count) {
            guard windowEquals(hay, i, termTokens) else { continue }
            if !isExcepted(hay, start: i, len: termTokens.count, exceptions: exceptions) {
                return true
            }
        }
        return false
    }

    private static func windowEquals(_ hay: [String], _ start: Int, _ term: [String]) -> Bool {
        guard start + term.count <= hay.count else { return false }
        for j in 0..<term.count where hay[start + j] != term[j] { return false }
        return true
    }

    private static func isExcepted(
        _ hay: [String],
        start: Int,
        len: Int,
        exceptions: [String]
    ) -> Bool {
        for ex in exceptions {
            let exTokens = tokenize(ex)
            guard !exTokens.isEmpty, hay.count >= exTokens.count else { continue }
            for i in 0...(hay.count - exTokens.count) {
                let overlaps = i < start + len && i + exTokens.count > start
                if overlaps && windowEquals(hay, i, exTokens) { return true }
            }
        }
        return false
    }
}
