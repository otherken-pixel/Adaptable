import Foundation

/// Demo Mode backend — a seeded, UserDefaults-persisted store used when no
/// Supabase config is present. Lets anyone run the full product loop
/// (generate → render → vote → save) with zero configuration. Mirrors
/// `src/lib/demo.ts`.
@MainActor
final class DemoStore {
    static let shared = DemoStore()

    static let demoUser = Profile(
        id: "demo-user",
        username: "you",
        avatar_url: nil,
        preferences: .empty,
        created_at: ISO8601DateFormatter().string(from: Date())
    )

    private struct Chef {
        let id: String
        let username: String
    }

    private let chefs: [String: Chef] = [
        "mika": Chef(id: "chef-mika", username: "mika.eats"),
        "theo": Chef(id: "chef-theo", username: "theo_cooks"),
        "june": Chef(id: "chef-june", username: "june.bakes"),
        "rafa": Chef(id: "chef-rafa", username: "rafa.fuego"),
    ]

    private struct State: Codable {
        var recipes: [Recipe]
        var votes: [String: Int]
        var saves: [String]
        var comments: [Comment]
        var notifications: [AppNotification]
        var plans: [MealPlanEntry]
        var preferences: Preferences
        var follows: [String]
    }

    private var state: State
    private var listeners: [(UUID, () -> Void)] = []
    private var genCount = 0
    private let key = "adaptable.demo.v2"

    private init() {
        if let raw = UserDefaults.standard.data(forKey: "adaptable.demo.v2"),
           let decoded = try? JSONDecoder().decode(State.self, from: raw) {
            state = decoded
        } else {
            state = DemoStore.seedState()
        }
    }

    // MARK: - Subscription

    @discardableResult
    func subscribe(_ fn: @escaping () -> Void) -> () -> Void {
        let token = UUID()
        listeners.append((token, fn))
        return { [weak self] in self?.listeners.removeAll { $0.0 == token } }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
        for (_, fn) in listeners { fn() }
    }

    // MARK: - Recipes

    func listRecipes() -> [Recipe] { state.recipes }
    func getRecipe(_ id: String) -> Recipe? { state.recipes.first { $0.id == id } }

    func addRecipe(_ recipe: Recipe) {
        state.recipes.insert(recipe, at: 0)
        persist()
    }

    // MARK: - Votes

    func getVotes() -> [String: Int] { state.votes }

    func setVote(_ recipeId: String, value: Int?) {
        let prev = state.votes[recipeId] ?? 0
        let next = value ?? 0
        if value == nil { state.votes.removeValue(forKey: recipeId) } else { state.votes[recipeId] = value }
        state.recipes = state.recipes.map {
            var r = $0
            if r.id == recipeId { r.net_upvotes = r.net_upvotes - prev + next }
            return r
        }
        persist()
    }

    // MARK: - Saves

    func getSaves() -> [String] { state.saves }

    @discardableResult
    func toggleSave(_ recipeId: String) -> Bool {
        let saved = state.saves.contains(recipeId)
        if saved {
            state.saves.removeAll { $0 == recipeId }
        } else {
            state.saves.insert(recipeId, at: 0)
        }
        persist()
        return !saved
    }

    // MARK: - Comments

    func listComments(_ recipeId: String) -> [Comment] {
        state.comments
            .filter { $0.recipe_id == recipeId }
            .sorted { $0.created_at > $1.created_at }
    }

    func addComment(_ recipeId: String, body: String) -> Comment {
        let comment = Comment(
            id: "c-\(Int(Date().timeIntervalSince1970 * 1000))",
            recipe_id: recipeId,
            user_id: DemoStore.demoUser.id,
            body: body,
            created_at: ISO8601DateFormatter().string(from: Date()),
            author: DemoStore.demoUser.lite
        )
        state.comments.insert(comment, at: 0)
        state.recipes = state.recipes.map {
            var r = $0
            if r.id == recipeId { r.comment_count += 1 }
            return r
        }
        persist()
        return comment
    }

    func deleteComment(_ commentId: String) {
        guard let target = state.comments.first(where: { $0.id == commentId }) else { return }
        state.comments.removeAll { $0.id == commentId }
        state.recipes = state.recipes.map {
            var r = $0
            if r.id == target.recipe_id { r.comment_count = max(0, r.comment_count - 1) }
            return r
        }
        persist()
    }

    // MARK: - Cooks

    func recordCook(_ recipeId: String) {
        state.recipes = state.recipes.map {
            var r = $0
            if r.id == recipeId { r.cook_count += 1 }
            return r
        }
        persist()
    }

    // MARK: - Meal plans

    func listPlans() -> [MealPlanEntry] {
        state.plans.map {
            var p = $0
            p.recipe = state.recipes.first { $0.id == p.recipe_id }
            return p
        }
    }

    @discardableResult
    func addPlan(_ recipeId: String, planDate: String, servings: Int) -> MealPlanEntry {
        let entry = MealPlanEntry(
            id: "p-\(Int(Date().timeIntervalSince1970 * 1000))-\(Int.random(in: 1000...9999))",
            user_id: DemoStore.demoUser.id,
            recipe_id: recipeId,
            plan_date: planDate,
            servings: servings,
            created_at: ISO8601DateFormatter().string(from: Date()),
            recipe: nil
        )
        state.plans.append(entry)
        persist()
        return entry
    }

    func updatePlanServings(_ id: String, servings: Int) {
        state.plans = state.plans.map {
            var p = $0
            if p.id == id { p.servings = servings }
            return p
        }
        persist()
    }

    func removePlan(_ id: String) {
        state.plans.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Preferences

    func getPreferences() -> Preferences { state.preferences }
    func setPreferences(_ prefs: Preferences) {
        state.preferences = prefs
        persist()
    }

    // MARK: - Follows

    func getFollows() -> [String] { state.follows }

    @discardableResult
    func toggleFollow(_ chefId: String) -> Bool {
        let following = state.follows.contains(chefId)
        if following { state.follows.removeAll { $0 == chefId } } else { state.follows.append(chefId) }
        persist()
        return !following
    }

    // MARK: - Notifications

    func listNotifications() -> [AppNotification] {
        state.notifications.sorted { $0.created_at > $1.created_at }
    }

    func markNotificationsRead() {
        state.notifications = state.notifications.map {
            var n = $0
            n.read = true
            return n
        }
        persist()
    }

    // MARK: - Simulated community engagement

    private func pushNotification(type: NotificationKind, actor: Chef, recipeId: String) {
        guard let recipe = state.recipes.first(where: { $0.id == recipeId }) else { return }
        let notification = AppNotification(
            id: "n-\(Int(Date().timeIntervalSince1970 * 1000))-\(Int.random(in: 1000...9999))",
            user_id: DemoStore.demoUser.id,
            actor_id: actor.id,
            recipe_id: recipe.id,
            type: type,
            read: false,
            created_at: ISO8601DateFormatter().string(from: Date()),
            actor: ProfileLite(id: actor.id, username: actor.username, avatar_url: nil),
            recipe: RecipeLite(id: recipe.id, title: recipe.title, emoji: recipe.emoji)
        )
        state.notifications.insert(notification, at: 0)

        switch type {
        case .vote:
            state.recipes = state.recipes.map {
                var r = $0
                if r.id == recipe.id { r.net_upvotes += 1 }
                return r
            }
        case .cook:
            state.recipes = state.recipes.map {
                var r = $0
                if r.id == recipe.id { r.cook_count += 1 }
                return r
            }
        case .comment:
            let comment = Comment(
                id: "c-\(Int(Date().timeIntervalSince1970 * 1000))",
                recipe_id: recipe.id,
                user_id: actor.id,
                body: "Made this from your post — turned out fantastic. Instant save! 🔥",
                created_at: ISO8601DateFormatter().string(from: Date()),
                author: ProfileLite(id: actor.id, username: actor.username, avatar_url: nil)
            )
            state.comments.insert(comment, at: 0)
            state.recipes = state.recipes.map {
                var r = $0
                if r.id == recipe.id { r.comment_count += 1 }
                return r
            }
        }
        persist()
    }

    private func simulateEngagement(recipeId: String) {
        guard let rafa = chefs["rafa"], let mika = chefs["mika"], let theo = chefs["theo"], let june = chefs["june"] else { return }
        schedule(after: 7) { [weak self] in self?.pushNotification(type: .vote, actor: rafa, recipeId: recipeId) }
        schedule(after: 16) { [weak self] in self?.pushNotification(type: .comment, actor: mika, recipeId: recipeId) }
        schedule(after: 28) { [weak self] in self?.pushNotification(type: .cook, actor: theo, recipeId: recipeId) }
        schedule(after: 40) { [weak self] in self?.pushNotification(type: .vote, actor: june, recipeId: recipeId) }
    }

    private func schedule(after seconds: Double, _ action: @escaping () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            action()
        }
    }

    // MARK: - Demo recipe generation (no API key required)

    func generate(prompt: String, servings: Int?) async -> Recipe {
        try? await Task.sleep(nanoseconds: UInt64((2.6 + Double.random(in: 0...1.2)) * 1_000_000_000))
        let template = DemoStore.templates[genCount % DemoStore.templates.count]
        genCount += 1
        let targetServings = (servings.map { $0 >= 1 && $0 <= 12 } ?? false) ? servings! : template.servings
        let factor = Double(targetServings) / Double(template.servings)
        var recipe = template
        recipe.servings = targetServings
        if abs(factor - 1) > 1e-9 {
            recipe.ingredients = template.ingredients.map {
                var i = $0
                i.quantity = Quantity.scale(i.quantity, factor: factor)
                return i
            }
        }
        recipe.id = "gen-\(Int(Date().timeIntervalSince1970 * 1000))"
        recipe.author_id = DemoStore.demoUser.id
        recipe.author = DemoStore.demoUser.lite
        recipe.source_prompt = prompt
        recipe.net_upvotes = 0
        recipe.cook_count = 0
        recipe.comment_count = 0
        recipe.created_at = ISO8601DateFormatter().string(from: Date())
        addRecipe(recipe)
        simulateEngagement(recipeId: recipe.id)
        return recipe
    }

    func importRecipe(url: String?, hasText: Bool) async -> Recipe {
        try? await Task.sleep(nanoseconds: UInt64((2.2 + Double.random(in: 0...0.9)) * 1_000_000_000))
        let template = DemoStore.templates[genCount % DemoStore.templates.count]
        genCount += 1
        var recipe = template
        recipe.id = "imp-\(Int(Date().timeIntervalSince1970 * 1000))"
        recipe.author_id = DemoStore.demoUser.id
        recipe.author = DemoStore.demoUser.lite
        recipe.source_prompt = ""
        recipe.source_url = url
        recipe.net_upvotes = 0
        recipe.cook_count = 0
        recipe.comment_count = 0
        recipe.created_at = ISO8601DateFormatter().string(from: Date())
        addRecipe(recipe)
        return recipe
    }

    // MARK: - Seed data

    private static func daysAgo(_ n: Double) -> String {
        ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -n * 86_400))
    }

    // MARK: - JSON-driven seed content
    //
    // All 30 seed recipes (and their review comments) are authored once in
    // shared/seed-recipes.json — the same file that generates the live
    // Supabase seed migration (see scripts/generate-seed-sql.py) — bundled
    // into the app via the Xcode project's "Shared" group. Demo Mode and
    // the live backend always show identical content.

    private struct SeedChefEntry: Decodable { let username: String; let existing: Bool }
    private struct SeedCommentEntry: Decodable { let author: String; let body: String }
    private struct SeedRecipeEntry: Decodable {
        let id: String
        let author: String
        let title: String
        let description: String
        let emoji: String
        let cuisine: String
        let difficulty: Difficulty
        let prep_time_minutes: Int
        let cook_time_minutes: Int
        let servings: Int
        let calories: Int
        let protein_g: Int
        let carbs_g: Int
        let fat_g: Int
        let tags: [String]
        let ingredients: [Ingredient]
        let steps: [RecipeStep]
        let source_prompt: String
        let net_upvotes: Int
        let cook_count: Int
        let comment_count: Int
        let days_ago: Double
        let comments: [SeedCommentEntry]
    }
    private struct SeedDataFile: Decodable { let chefs: [SeedChefEntry]; let recipes: [SeedRecipeEntry] }

    // Stable ids matching the ones this app has always used, so a
    // returning Demo Mode user's persisted UserDefaults state stays valid.
    private static let chefIdOverrides: [String: String] = [
        "mika.eats": "chef-mika",
        "theo_cooks": "chef-theo",
        "june.bakes": "chef-june",
        "rafa.fuego": "chef-rafa",
    ]

    private static func chefId(for username: String) -> String {
        if let override = chefIdOverrides[username] { return override }
        let slug = username.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
        return "chef-\(slug)"
    }

    private static func loadSeedData() -> SeedDataFile {
        guard let url = Bundle.main.url(forResource: "seed-recipes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(SeedDataFile.self, from: data) else {
            assertionFailure("shared/seed-recipes.json failed to load or decode from the app bundle")
            return SeedDataFile(chefs: [], recipes: [])
        }
        return decoded
    }

    private static func seedState() -> State {
        let data = loadSeedData()
        var chefsByUsername: [String: ProfileLite] = [:]
        for c in data.chefs {
            chefsByUsername[c.username] = ProfileLite(id: chefId(for: c.username), username: c.username, avatar_url: nil)
        }

        let recipes: [Recipe] = data.recipes.map { r in
            let author = chefsByUsername[r.author]
            return Recipe(
                id: r.id,
                author_id: author?.id ?? "",
                title: r.title,
                description: r.description,
                emoji: r.emoji,
                cuisine: r.cuisine,
                difficulty: r.difficulty,
                prep_time_minutes: r.prep_time_minutes,
                cook_time_minutes: r.cook_time_minutes,
                servings: r.servings,
                calories: r.calories,
                protein_g: r.protein_g,
                carbs_g: r.carbs_g,
                fat_g: r.fat_g,
                tags: r.tags,
                ingredients: r.ingredients,
                steps: r.steps,
                source_prompt: r.source_prompt,
                source_url: nil,
                net_upvotes: r.net_upvotes,
                cook_count: r.cook_count,
                comment_count: r.comment_count,
                created_at: daysAgo(r.days_ago),
                author: author
            )
        }

        // Comments are staggered between the recipe's creation and now
        // (25/50/75% of the way through), matching the fractions used by
        // the live-DB seed.
        let comments: [Comment] = data.recipes.flatMap { r -> [Comment] in
            let n = r.comments.count
            return r.comments.enumerated().map { i, c in
                let author = chefsByUsername[c.author]
                let frac = Double(i + 1) / Double(n + 1)
                return Comment(
                    id: "c-seed-\(r.id)-\(i)",
                    recipe_id: r.id,
                    user_id: author?.id ?? "",
                    body: c.body,
                    created_at: daysAgo(r.days_ago * (1 - frac)),
                    author: author
                )
            }
        }

        return State(
            recipes: recipes,
            votes: [:],
            saves: [],
            comments: comments,
            notifications: [],
            plans: [],
            preferences: .empty,
            follows: []
        )
    }

    /// Demo generation/import templates — a small rotation of complete
    /// recipes returned instead of a live Gemini call.
    private static let templates: [Recipe] = [
        Recipe(
            id: "", author_id: "", title: "Charred Corn & Halloumi Grain Bowl",
            description: "Squeaky golden halloumi, blistered corn and a lime-honey dressing over herby grains — built from your request.",
            emoji: "🥗", cuisine: "Mediterranean", difficulty: .easy,
            prep_time_minutes: 10, cook_time_minutes: 12, servings: 2,
            calories: 490, protein_g: 22, carbs_g: 45, fat_g: 24,
            tags: ["Vegetarian", "Meal-prep", "Fresh"],
            ingredients: [
                Ingredient(item: "Halloumi", quantity: "200 g (7 oz)", note: "thick slices"),
                Ingredient(item: "Corn", quantity: "2 cobs", note: "kernels removed"),
                Ingredient(item: "Cooked farro or quinoa", quantity: "2 cups", note: nil),
                Ingredient(item: "Lime", quantity: "1", note: "juiced"),
                Ingredient(item: "Honey", quantity: "1 tsp", note: nil),
                Ingredient(item: "Mint + parsley", quantity: "a big handful", note: "chopped"),
            ],
            steps: [
                RecipeStep(step: 1, instruction: "Char corn kernels in a dry hot pan 4 minutes until spotted black. Remove.", tip: nil),
                RecipeStep(step: 2, instruction: "Sear halloumi slices 2 minutes per side until deeply golden.", tip: "No oil needed — halloumi releases its own."),
                RecipeStep(step: 3, instruction: "Whisk lime juice, honey, 2 tbsp olive oil and a pinch of salt.", tip: nil),
                RecipeStep(step: 4, instruction: "Toss grains with herbs and half the dressing; top with corn, halloumi and the rest.", tip: nil),
            ],
            source_prompt: "", source_url: nil, net_upvotes: 0, cook_count: 0, comment_count: 0,
            created_at: "", author: nil
        ),
        Recipe(
            id: "", author_id: "", title: "Sticky Gochujang Meatballs",
            description: "Glazed, gingery and gone in minutes. Serve over rice with quick-pickled cucumbers.",
            emoji: "🍢", cuisine: "Korean-inspired", difficulty: .medium,
            prep_time_minutes: 15, cook_time_minutes: 15, servings: 4,
            calories: 520, protein_g: 34, carbs_g: 42, fat_g: 20,
            tags: ["High-protein", "Sweet & spicy", "Weeknight"],
            ingredients: [
                Ingredient(item: "Ground chicken or pork", quantity: "500 g (1 lb)", note: nil),
                Ingredient(item: "Panko", quantity: "½ cup", note: nil),
                Ingredient(item: "Egg", quantity: "1", note: nil),
                Ingredient(item: "Scallions", quantity: "4", note: "minced, whites and greens separated"),
                Ingredient(item: "Gochujang", quantity: "3 tbsp", note: nil),
                Ingredient(item: "Honey + soy + rice vinegar", quantity: "2 tbsp each", note: nil),
                Ingredient(item: "Garlic + ginger", quantity: "2 cloves + 1 inch", note: "grated"),
            ],
            steps: [
                RecipeStep(step: 1, instruction: "Mix meat, panko, egg, scallion whites, half the garlic-ginger and a pinch of salt. Roll into 16 balls.", tip: nil),
                RecipeStep(step: 2, instruction: "Sear meatballs in a wide pan until browned all over, about 6 minutes.", tip: nil),
                RecipeStep(step: 3, instruction: "Whisk gochujang, honey, soy, vinegar and remaining garlic-ginger with ¼ cup water; pour over and simmer 6 minutes until sticky.", tip: "The glaze should coat the back of a spoon."),
                RecipeStep(step: 4, instruction: "Shower with scallion greens and sesame. Serve over rice.", tip: nil),
            ],
            source_prompt: "", source_url: nil, net_upvotes: 0, cook_count: 0, comment_count: 0,
            created_at: "", author: nil
        ),
        Recipe(
            id: "", author_id: "", title: "Crispy Gnocchi with Burst Tomatoes",
            description: "Shelf-stable gnocchi pan-fried until golden, tossed with jammy burst tomatoes and torn mozzarella.",
            emoji: "🍅", cuisine: "Italian", difficulty: .easy,
            prep_time_minutes: 5, cook_time_minutes: 15, servings: 2,
            calories: 540, protein_g: 18, carbs_g: 62, fat_g: 22,
            tags: ["Vegetarian", "One-pan", "20-minute"],
            ingredients: [
                Ingredient(item: "Shelf-stable gnocchi", quantity: "500 g (1 lb)", note: nil),
                Ingredient(item: "Cherry tomatoes", quantity: "300 g (2 cups)", note: nil),
                Ingredient(item: "Garlic", quantity: "3 cloves", note: "sliced"),
                Ingredient(item: "Fresh mozzarella", quantity: "125 g (1 ball)", note: "torn"),
                Ingredient(item: "Basil", quantity: "a handful", note: nil),
                Ingredient(item: "Chili flakes", quantity: "a pinch", note: nil),
            ],
            steps: [
                RecipeStep(step: 1, instruction: "Pan-fry gnocchi in olive oil, untouched, 3 minutes per side until golden and crisp. Remove.", tip: "Don't boil them — straight into the pan."),
                RecipeStep(step: 2, instruction: "Add tomatoes, garlic and chili to the pan; cook until tomatoes burst and go jammy, 6 minutes.", tip: nil),
                RecipeStep(step: 3, instruction: "Crush a few tomatoes, return gnocchi, toss to coat.", tip: nil),
                RecipeStep(step: 4, instruction: "Off heat, tuck in mozzarella and basil. Season and serve from the pan.", tip: nil),
            ],
            source_prompt: "", source_url: nil, net_upvotes: 0, cook_count: 0, comment_count: 0,
            created_at: "", author: nil
        ),
    ]
}
