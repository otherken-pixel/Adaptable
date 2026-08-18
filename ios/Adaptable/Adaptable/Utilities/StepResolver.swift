import Foundation

/// One ingredient the cook needs for the current step, with scaled quantity.
struct StepIngredientUse: Identifiable, Equatable {
    enum Source: Equatable {
        case recipe
        case pantry
        case yield
    }

    let item: String
    let quantity: String
    let note: String?
    let source: Source
    /// Index into `recipe.ingredients` when `source == .recipe`.
    let recipeIndex: Int?

    var id: String { "\(source)-\(item)-\(recipeIndex ?? -1)" }
}

/// Kitchen-ready view of a recipe step: actions, quantities, timers, cues.
/// Structured fields on `RecipeStep` win; everything else is inferred from
/// instruction text so existing recipes (and Gemini output) still work.
struct ResolvedStep {
    let number: Int
    let total: Int
    let instruction: String
    let tip: String?
    let actions: [String]
    let ingredients: [StepIngredientUse]
    let timers: [ExtractedTimer]
    let temperature: String?
    let equipment: [String]
    let lookFor: String?
    let yieldNote: String?
    let meanwhile: String?
    let safety: String?
}

enum StepResolver {
    private static let stopwords: Set<String> = [
        "a", "an", "the", "and", "or", "of", "with", "for", "to", "in", "on",
        "plus", "some", "any", "optional", "into", "from", "each", "per",
        "over", "until", "then", "into", "off", "up", "at",
    ]

    private static let equipmentPatterns: [(String, String)] = [
        ("air[- ]?fryer", "Air fryer"),
        ("baking dish", "Baking dish"),
        ("sheet pan", "Sheet pan"),
        ("sheet-pan", "Sheet pan"),
        (#"\b8\s*[x×]\s*8\b"#, "8×8-inch pan"),
        ("dutch oven", "Dutch oven"),
        ("mixing bowl", "Mixing bowl"),
        ("large pot", "Large pot"),
        ("large skillet", "Large skillet"),
        ("large pan", "Large pan"),
        (#"\bwok\b"#, "Wok"),
        (#"\bskillet\b"#, "Skillet"),
        (#"\bsaucepan\b"#, "Saucepan"),
        (#"\bcolander\b"#, "Colander"),
        ("parchment", "Parchment"),
        (#"\boven\b"#, "Oven"),
        (#"\bgrill\b"#, "Grill"),
    ]

    static func resolve(
        step: RecipeStep,
        number: Int,
        total: Int,
        recipe: Recipe,
        factor: Double,
        substitutions: [String: String] = [:],
        nextStep: RecipeStep? = nil
    ) -> ResolvedStep {
        let rawInstruction = applySubstitutions(step.instruction, substitutions)
        let tip = step.tip.map { applySubstitutions($0, substitutions) }
        let haystack = [rawInstruction, tip ?? ""].joined(separator: " ")

        let actions = splitActions(rawInstruction)
        let ingredients = matchIngredients(
            step: step,
            haystack: haystack,
            recipe: recipe,
            factor: factor,
            substitutions: substitutions
        )
        var timers = timersFor(step: step, haystack: haystack)
        let temperature = step.temperature?.nilIfEmpty ?? DurationParser.extractTemperature(haystack)
        if DurationParser.mentionsPreheat(haystack), !timers.contains(where: { $0.kind == .preheat }) {
            timers.insert(
                ExtractedTimer(seconds: DurationParser.defaultPreheatSeconds, label: "Oven preheat", kind: .preheat),
                at: 0
            )
        }
        let equipment = (step.equipment?.filter { !$0.isEmpty }).nonEmpty
            ?? detectEquipment(haystack)
        let lookFor = step.look_for?.nilIfEmpty ?? detectLookFor(rawInstruction, tip: tip)
        let yieldNote = detectYield(rawInstruction)
        let meanwhile = detectMeanwhile(current: rawInstruction, next: nextStep?.instruction)
        let safety = detectSafety(haystack)

        return ResolvedStep(
            number: number,
            total: total,
            instruction: rawInstruction,
            tip: tip,
            actions: actions,
            ingredients: ingredients,
            timers: timers,
            temperature: temperature,
            equipment: equipment,
            lookFor: lookFor,
            yieldNote: yieldNote,
            meanwhile: meanwhile,
            safety: safety
        )
    }

    // MARK: - Actions

    static func splitActions(_ instruction: String) -> [String] {
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let pieces = trimmed
            .replacingOccurrences(of: #"[;•]"#, with: ".", options: .regularExpression)
            .components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "."))) }
            .filter { $0.count >= 8 }
        return pieces.isEmpty ? [trimmed] : pieces
    }

    // MARK: - Ingredients

    static func matchIngredients(
        step: RecipeStep,
        haystack: String,
        recipe: Recipe,
        factor: Double,
        substitutions: [String: String]
    ) -> [StepIngredientUse] {
        let all = recipe.ingredients ?? []
        var used: [StepIngredientUse] = []
        var claimed = Set<Int>()
        let lower = haystack.lowercased()

        if let named = step.ingredients_used, !named.isEmpty {
            for name in named {
                if let (i, ing) = bestNamedMatch(name, in: all), !claimed.contains(i) {
                    claimed.insert(i)
                    used.append(use(ing, index: i, factor: factor, substitutions: substitutions, source: .recipe))
                }
            }
        }

        for (i, ing) in all.enumerated() where !claimed.contains(i) {
            if ingredientMentioned(ing.item, in: lower) {
                claimed.insert(i)
                used.append(use(ing, index: i, factor: factor, substitutions: substitutions, source: .recipe))
            }
        }

        // Pantry staples named in the step but missing from the shopping list.
        for staple in ["salt", "black pepper", "pepper", "pasta water", "water", "lime", "flaky salt"] {
            if staple == "water" && lower.contains("pasta water") { continue }
            if used.contains(where: { $0.item.lowercased().contains(staple) }) { continue }
            if all.contains(where: { $0.item.lowercased().contains(staple) }) { continue }
            if wordBoundary(staple, in: lower) {
                let quantity: String
                let source: StepIngredientUse.Source
                if staple == "pasta water" {
                    quantity = detectPastaWaterAmount(haystack) ?? "as needed"
                    source = .yield
                } else if staple == "salt" || staple.contains("pepper") {
                    quantity = "to taste"
                    source = .pantry
                } else {
                    quantity = "as needed"
                    source = .pantry
                }
                used.append(StepIngredientUse(item: staple.capitalized, quantity: quantity, note: nil, source: source, recipeIndex: nil))
            }
        }

        return used
    }

    private static func use(
        _ ing: Ingredient,
        index: Int,
        factor: Double,
        substitutions: [String: String],
        source: StepIngredientUse.Source
    ) -> StepIngredientUse {
        let item = substitutions[ing.item] ?? ing.item
        return StepIngredientUse(
            item: item,
            quantity: Quantity.scale(ing.quantity, factor: factor),
            note: ing.note,
            source: source,
            recipeIndex: index
        )
    }

    private static func bestNamedMatch(_ name: String, in all: [Ingredient]) -> (Int, Ingredient)? {
        let needle = name.lowercased()
        if let exact = all.enumerated().first(where: { $0.element.item.lowercased() == needle }) {
            return (exact.offset, exact.element)
        }
        return all.enumerated().first(where: {
            $0.element.item.lowercased().contains(needle) || needle.contains($0.element.item.lowercased())
        }).map { ($0.offset, $0.element) }
    }

    static func ingredientMentioned(_ item: String, in haystackLower: String) -> Bool {
        let tokens = tokenize(item).filter { $0.count >= 3 && !stopwords.contains($0) }
        if tokens.isEmpty { return false }
        let full = item.lowercased()
        if haystackLower.contains(full) { return true }
        // Combined "Garlic + ginger" / "Penne or fusilli": match if any distinctive token appears.
        let distinctive = tokens.filter { $0.count >= 4 }
        if distinctive.count >= 2 {
            return distinctive.contains { wordBoundary($0, in: haystackLower) }
        }
        if let longest = (distinctive + tokens).max(by: { $0.count < $1.count }), longest.count >= 4 {
            return wordBoundary(longest, in: haystackLower)
        }
        // Short last tokens like "oil", "feta", "basil".
        if let last = tokens.last, last.count >= 3 {
            return wordBoundary(last, in: haystackLower)
        }
        return false
    }

    // MARK: - Timers

    private static func timersFor(step: RecipeStep, haystack: String) -> [ExtractedTimer] {
        let parsed = DurationParser.extractAllTimers(from: haystack)
        if let structured = step.duration_seconds, !structured.isEmpty {
            return structured.enumerated().map { i, secs in
                if parsed.indices.contains(i) {
                    return ExtractedTimer(seconds: secs, label: parsed[i].label, kind: parsed[i].kind)
                }
                return ExtractedTimer(seconds: secs, label: structured.count == 1 ? "Step timer" : "Timer \(i + 1)", kind: .other)
            }
        }
        return parsed
    }

    // MARK: - Equipment / cues

    private static func detectEquipment(_ text: String) -> [String] {
        var out: [String] = []
        for (pattern, label) in equipmentPatterns {
            if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil,
               !out.contains(label) {
                out.append(label)
            }
        }
        return out
    }

    private static func detectLookFor(_ instruction: String, tip: String?) -> String? {
        if let m = firstCapture(#"\buntil\s+([^.]+)"#, in: instruction) {
            let cue = m.trimmingCharacters(in: .whitespacesAndNewlines)
            if cue.count >= 8 && cue.count <= 140 { return cue }
        }
        if let tip, tip.range(of: #"\b(until|look|should|when it's|when it)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return tip
        }
        return nil
    }

    private static func detectYield(_ instruction: String) -> String? {
        if let m = firstCapture(#"reserv(?:e|ing)\s+([^.]+)"#, in: instruction) {
            return "Reserve \(m.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        if instruction.range(of: #"\bset aside\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return "Set this aside — you'll use it in a later step"
        }
        if instruction.range(of: #"\bremove\b.+\b(plate|bowl|aside)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return "Remove and hold for a later step"
        }
        return nil
    }

    private static func detectPastaWaterAmount(_ text: String) -> String? {
        firstCapture(#"reserv(?:e|ing)\s+([^.,]+pasta water)"#, in: text)
            ?? firstCapture(#"(\d[^\s]*\s*(?:cup|cups)\s+pasta water)"#, in: text)
    }

    private static func detectMeanwhile(current: String, next: String?) -> String? {
        if let next, next.range(of: #"^\s*meanwhile\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return next.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if current.range(of: #"\bmeanwhile\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return nil
        }
        return nil
    }

    private static func detectSafety(_ text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("sushi-grade") || lower.contains("sashimi-grade") || lower.contains("sushi grade") {
            return "Use sushi- or sashimi-grade fish from a trusted counter for eating raw."
        }
        if let temp = firstCapture(#"(internal temp(?:erature)?(?: hits| reaches| to)?\s*[^.]+)"#, in: text) {
            return temp
        }
        if lower.contains("165°") || lower.contains("165 °") || lower.contains("74°") {
            return "Cook until the internal temperature reaches 165°F (74°C)."
        }
        if lower.contains("don't burn") || lower.contains("do not burn") || lower.contains("watch closely") {
            return text.range(of: #"[^.]*\b(burn|watch closely)[^.]*"#, options: [.regularExpression, .caseInsensitive])
                .map { String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        return nil
    }

    // MARK: - Text helpers

    static func applySubstitutions(_ text: String, _ substitutions: [String: String]) -> String {
        guard !substitutions.isEmpty else { return text }
        var result = text
        for (from, to) in substitutions where from.lowercased() != to.lowercased() {
            result = result.replacingOccurrences(of: from, with: to, options: .caseInsensitive)
        }
        return result
    }

    private static func tokenize(_ item: String) -> [String] {
        item.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9+\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[+/]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func wordBoundary(_ word: String, in haystackLower: String) -> Bool {
        haystackLower.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: word) + #"\b"#, options: .regularExpression) != nil
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1, m.range(at: 1).location != NSNotFound else { return nil }
        return ns.substring(with: m.range(at: 1))
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

private extension Optional where Wrapped == [String] {
    var nonEmpty: [String]? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
