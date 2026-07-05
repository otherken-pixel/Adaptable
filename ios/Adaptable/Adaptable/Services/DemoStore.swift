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
    private let key = "adaptable.demo.v1"

    private init() {
        if let raw = UserDefaults.standard.data(forKey: "adaptable.demo.v1"),
           let decoded = try? JSONDecoder().decode(State.self, from: raw) {
            state = decoded
        } else {
            state = DemoStore.seedState(chefs: [
                "mika": Chef(id: "chef-mika", username: "mika.eats"),
                "theo": Chef(id: "chef-theo", username: "theo_cooks"),
                "june": Chef(id: "chef-june", username: "june.bakes"),
                "rafa": Chef(id: "chef-rafa", username: "rafa.fuego"),
            ])
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

    private static func seedState(chefs: [String: Chef]) -> State {
        let recipes = seedRecipes(chefs: chefs)
        return State(
            recipes: recipes,
            votes: [:],
            saves: [],
            comments: seedComments(chefs: chefs),
            notifications: [],
            plans: [],
            preferences: .empty,
            follows: []
        )
    }

    private static func seedRecipes(chefs: [String: Chef]) -> [Recipe] {
        let mika = chefs["mika"]!.id, theo = chefs["theo"]!.id, rafa = chefs["rafa"]!.id, june = chefs["june"]!.id
        func lite(_ id: String) -> ProfileLite {
            let username = chefs.values.first { $0.id == id }?.username ?? "chef"
            return ProfileLite(id: id, username: username, avatar_url: nil)
        }

        return [
            Recipe(
                id: "seed-miso-salmon", author_id: mika,
                title: "Caramelized Miso Salmon Bowl",
                description: "Silky salmon lacquered in sweet-savory miso glaze over sushi rice with quick-pickled cucumber. Weeknight fancy in 25 minutes.",
                emoji: "🍣", cuisine: "Japanese", difficulty: .easy,
                prep_time_minutes: 10, cook_time_minutes: 15, servings: 2,
                calories: 560, protein_g: 38, carbs_g: 52, fat_g: 21,
                tags: ["High-protein", "Pescatarian", "Weeknight"],
                ingredients: [
                    Ingredient(item: "Salmon fillets", quantity: "2 × 150 g (5 oz)", note: "skin on"),
                    Ingredient(item: "White miso paste", quantity: "2 tbsp", note: nil),
                    Ingredient(item: "Maple syrup", quantity: "1 tbsp", note: nil),
                    Ingredient(item: "Soy sauce", quantity: "1 tbsp", note: nil),
                    Ingredient(item: "Rice vinegar", quantity: "2 tbsp", note: nil),
                    Ingredient(item: "Sushi rice", quantity: "150 g (¾ cup)", note: "rinsed"),
                    Ingredient(item: "Persian cucumber", quantity: "1", note: "ribboned"),
                    Ingredient(item: "Scallions + sesame", quantity: "to finish", note: nil),
                ],
                steps: [
                    RecipeStep(step: 1, instruction: "Cook the rice. While it steams, whisk miso, maple, soy and 1 tbsp water into a glossy glaze.", tip: nil),
                    RecipeStep(step: 2, instruction: "Toss cucumber ribbons with rice vinegar and a pinch of salt. Set aside to pickle.", tip: "A pinch of sugar rounds out the pickle."),
                    RecipeStep(step: 3, instruction: "Sear salmon skin-side down 4 minutes in a hot pan. Flip, brush thickly with glaze, cook 3 more minutes.", tip: nil),
                    RecipeStep(step: 4, instruction: "Broil 90 seconds until the glaze bubbles and caramelizes at the edges.", tip: "Watch closely — miso goes from bronzed to burnt fast."),
                    RecipeStep(step: 5, instruction: "Build bowls: rice, salmon, drained pickles. Shower with scallions and sesame.", tip: nil),
                ],
                source_prompt: "quick high-protein salmon dinner", source_url: nil,
                net_upvotes: 482, cook_count: 214, comment_count: 3,
                created_at: daysAgo(6), author: lite(mika)
            ),
            Recipe(
                id: "seed-chickpea-curry", author_id: theo,
                title: "20-Minute Coconut Chickpea Curry",
                description: "Creamy, gently spiced and entirely from the pantry. The crispy chickpea topping is the move.",
                emoji: "🍛", cuisine: "Indian-ish", difficulty: .easy,
                prep_time_minutes: 5, cook_time_minutes: 15, servings: 4,
                calories: 430, protein_g: 16, carbs_g: 48, fat_g: 22,
                tags: ["Vegan", "Pantry", "One-pan", "Gluten-free"],
                ingredients: [
                    Ingredient(item: "Chickpeas", quantity: "2 cans (800 g)", note: "drained, ½ cup reserved"),
                    Ingredient(item: "Coconut milk", quantity: "1 can (400 ml)", note: "full fat"),
                    Ingredient(item: "Crushed tomatoes", quantity: "200 g (1 cup)", note: nil),
                    Ingredient(item: "Yellow onion", quantity: "1", note: "diced"),
                    Ingredient(item: "Garlic + ginger", quantity: "3 cloves + 1 inch", note: "grated"),
                    Ingredient(item: "Curry powder", quantity: "2 tbsp", note: nil),
                    Ingredient(item: "Baby spinach", quantity: "2 big handfuls", note: nil),
                ],
                steps: [
                    RecipeStep(step: 1, instruction: "Crisp the reserved chickpeas in olive oil with a pinch of curry powder and salt. Set aside.", tip: nil),
                    RecipeStep(step: 2, instruction: "In the same pan, soften onion 3 minutes. Add garlic, ginger and curry powder; bloom 60 seconds.", tip: "Toasting spices in oil unlocks their flavor."),
                    RecipeStep(step: 3, instruction: "Add tomatoes, coconut milk and chickpeas. Simmer 8 minutes until it thickens slightly.", tip: nil),
                    RecipeStep(step: 4, instruction: "Wilt in the spinach, season with salt and a squeeze of lime. Top with crispy chickpeas.", tip: nil),
                ],
                source_prompt: "vegan pantry curry in 20 minutes", source_url: nil,
                net_upvotes: 391, cook_count: 178, comment_count: 2,
                created_at: daysAgo(4), author: lite(theo)
            ),
            Recipe(
                id: "seed-smash-tacos", author_id: rafa,
                title: "Crispy Smash Burger Tacos",
                description: "A smash patty seared directly onto a tortilla — burger flavor, taco format, ridiculous crust.",
                emoji: "🌮", cuisine: "Tex-Mex", difficulty: .medium,
                prep_time_minutes: 15, cook_time_minutes: 10, servings: 4,
                calories: 610, protein_g: 33, carbs_g: 38, fat_g: 34,
                tags: ["Crowd-pleaser", "30-minute", "Beef"],
                ingredients: [
                    Ingredient(item: "Ground beef (80/20)", quantity: "500 g (1 lb)", note: nil),
                    Ingredient(item: "Small flour tortillas", quantity: "8", note: nil),
                    Ingredient(item: "American cheese", quantity: "8 slices", note: nil),
                    Ingredient(item: "White onion", quantity: "½", note: "shaved paper-thin"),
                    Ingredient(item: "Shredded lettuce", quantity: "2 cups", note: nil),
                    Ingredient(item: "Mayo + ketchup + pickle brine", quantity: "¼ cup + 2 tbsp + 1 tbsp", note: "burger sauce"),
                ],
                steps: [
                    RecipeStep(step: 1, instruction: "Stir the burger sauce together. Divide beef into 8 loose 60 g balls — don't compact them.", tip: nil),
                    RecipeStep(step: 2, instruction: "Press a beef ball thinly onto each tortilla so it reaches the edges.", tip: nil),
                    RecipeStep(step: 3, instruction: "Sear beef-side down in a screaming hot pan, pressing firmly, 2–3 minutes until deeply crusted.", tip: "A second pan on top makes a great press."),
                    RecipeStep(step: 4, instruction: "Flip, add cheese and onion, cook 1 minute until the tortilla crisps.", tip: nil),
                    RecipeStep(step: 5, instruction: "Fold, stuff with lettuce and sauce, eat immediately over the sink.", tip: nil),
                ],
                source_prompt: "smash burger tacos for four", source_url: nil,
                net_upvotes: 357, cook_count: 342, comment_count: 2,
                created_at: daysAgo(2), author: lite(rafa)
            ),
            Recipe(
                id: "seed-lemon-pasta", author_id: june,
                title: "One-Pot Lemon Ricotta Rigatoni",
                description: "Bright, creamy and done before the table is set. The pasta water does all the sauce work.",
                emoji: "🍋", cuisine: "Italian", difficulty: .easy,
                prep_time_minutes: 5, cook_time_minutes: 15, servings: 3,
                calories: 520, protein_g: 21, carbs_g: 68, fat_g: 18,
                tags: ["Vegetarian", "One-pot", "15-minute"],
                ingredients: [
                    Ingredient(item: "Rigatoni", quantity: "300 g (10 oz)", note: nil),
                    Ingredient(item: "Whole-milk ricotta", quantity: "250 g (1 cup)", note: nil),
                    Ingredient(item: "Lemon", quantity: "1", note: "zest + juice"),
                    Ingredient(item: "Parmesan", quantity: "40 g (½ cup)", note: "finely grated"),
                    Ingredient(item: "Black pepper", quantity: "lots", note: nil),
                    Ingredient(item: "Basil", quantity: "a handful", note: nil),
                ],
                steps: [
                    RecipeStep(step: 1, instruction: "Boil rigatoni in well-salted water until just shy of al dente. Reserve 1 cup of pasta water.", tip: nil),
                    RecipeStep(step: 2, instruction: "Whisk ricotta, parmesan, lemon zest and juice with ½ cup pasta water into a silky sauce.", tip: nil),
                    RecipeStep(step: 3, instruction: "Toss pasta with the sauce off-heat, loosening with more pasta water until it coats every tube.", tip: "Off-heat keeps the ricotta creamy instead of grainy."),
                    RecipeStep(step: 4, instruction: "Finish with basil, black pepper and a drizzle of good olive oil.", tip: nil),
                ],
                source_prompt: "easy vegetarian pasta with lemon", source_url: nil,
                net_upvotes: 289, cook_count: 96, comment_count: 1,
                created_at: daysAgo(1), author: lite(june)
            ),
            Recipe(
                id: "seed-breakfast-tacos", author_id: mika,
                title: "5-Minute Protein Breakfast Wrap",
                description: "Soft scramble, crispy cheese skirt, one pan, five minutes. 38 g of protein before your coffee cools.",
                emoji: "🌯", cuisine: "American", difficulty: .easy,
                prep_time_minutes: 2, cook_time_minutes: 3, servings: 1,
                calories: 520, protein_g: 38, carbs_g: 28, fat_g: 24,
                tags: ["High-protein", "Breakfast", "5-minute"],
                ingredients: [
                    Ingredient(item: "Eggs", quantity: "3", note: nil),
                    Ingredient(item: "Cottage cheese", quantity: "2 tbsp", note: "trust the process"),
                    Ingredient(item: "Large tortilla", quantity: "1", note: nil),
                    Ingredient(item: "Cheddar", quantity: "30 g (⅓ cup)", note: "shredded"),
                    Ingredient(item: "Hot sauce", quantity: "to taste", note: nil),
                ],
                steps: [
                    RecipeStep(step: 1, instruction: "Whisk eggs with cottage cheese and a pinch of salt. Soft-scramble over medium-low, stopping while glossy.", tip: nil),
                    RecipeStep(step: 2, instruction: "Push eggs aside, scatter cheddar in the pan, and lay the tortilla on top. 60 seconds makes a crispy cheese skirt.", tip: "The cheese glues the wrap shut."),
                    RecipeStep(step: 3, instruction: "Flip the tortilla cheese-side up, pile on eggs and hot sauce, roll tightly and sear the seam.", tip: nil),
                ],
                source_prompt: "fast high protein breakfast", source_url: nil,
                net_upvotes: 214, cook_count: 511, comment_count: 1,
                created_at: daysAgo(0.5), author: lite(mika)
            ),
            Recipe(
                id: "seed-mushroom-ramen", author_id: theo,
                title: "Midnight Garlic Butter Mushroom Ramen",
                description: "Instant noodles glow-up: umami-bomb broth, jammy egg, torched mushrooms. Better than the shop, cheaper than delivery.",
                emoji: "🍜", cuisine: "Japanese-ish", difficulty: .medium,
                prep_time_minutes: 10, cook_time_minutes: 40, servings: 2,
                calories: 540, protein_g: 19, carbs_g: 58, fat_g: 26,
                tags: ["Vegetarian", "Comfort", "Late-night"],
                ingredients: [
                    Ingredient(item: "Instant ramen", quantity: "2 packs", note: "noodles only"),
                    Ingredient(item: "Mixed mushrooms", quantity: "300 g (10 oz)", note: "torn"),
                    Ingredient(item: "Butter", quantity: "3 tbsp", note: nil),
                    Ingredient(item: "Garlic", quantity: "4 cloves", note: "sliced"),
                    Ingredient(item: "White miso", quantity: "1 tbsp", note: nil),
                    Ingredient(item: "Soy sauce", quantity: "2 tbsp", note: nil),
                    Ingredient(item: "Eggs", quantity: "2", note: "jammy-boiled 6:30"),
                    Ingredient(item: "Chili crisp", quantity: "to finish", note: nil),
                ],
                steps: [
                    RecipeStep(step: 1, instruction: "Boil eggs 6½ minutes, then ice bath. Peel when cool.", tip: nil),
                    RecipeStep(step: 2, instruction: "Sear mushrooms dry in a hot pan until deeply browned, then add butter and garlic and baste 2 minutes.", tip: "Dry pan first = maximum browning, zero sog."),
                    RecipeStep(step: 3, instruction: "Whisk miso and soy into 700 ml hot water. Simmer half the mushrooms in it 5 minutes.", tip: nil),
                    RecipeStep(step: 4, instruction: "Cook noodles in the broth 2 minutes. Bowl up with remaining mushrooms, halved eggs and chili crisp.", tip: nil),
                ],
                source_prompt: "fancy instant ramen with mushrooms", source_url: nil,
                net_upvotes: 176, cook_count: 88, comment_count: 1,
                created_at: daysAgo(0.2), author: lite(theo)
            ),
        ]
    }

    private static func seedComments(chefs: [String: Chef]) -> [Comment] {
        let mika = chefs["mika"]!, theo = chefs["theo"]!, rafa = chefs["rafa"]!, june = chefs["june"]!
        func lite(_ c: Chef) -> ProfileLite { ProfileLite(id: c.id, username: c.username, avatar_url: nil) }
        return [
            Comment(id: "c-1", recipe_id: "seed-miso-salmon", user_id: theo.id, body: "Made this twice this week. The broil step is not optional — that caramelized edge is everything.", created_at: daysAgo(4), author: lite(theo)),
            Comment(id: "c-2", recipe_id: "seed-miso-salmon", user_id: june.id, body: "Swapped maple for honey and it worked great. 10/10 weeknight dinner.", created_at: daysAgo(3), author: lite(june)),
            Comment(id: "c-3", recipe_id: "seed-miso-salmon", user_id: rafa.id, body: "Remixed this with gochujang instead of miso 🔥 highly recommend.", created_at: daysAgo(1), author: lite(rafa)),
            Comment(id: "c-4", recipe_id: "seed-chickpea-curry", user_id: mika.id, body: "The crispy chickpea topping is genius. Doubled it, no regrets.", created_at: daysAgo(2), author: lite(mika)),
            Comment(id: "c-5", recipe_id: "seed-chickpea-curry", user_id: june.id, body: "Used frozen spinach and it was still fantastic. True pantry hero.", created_at: daysAgo(1), author: lite(june)),
            Comment(id: "c-6", recipe_id: "seed-smash-tacos", user_id: mika.id, body: "\"Eat immediately over the sink\" — accurate. Family demolished these.", created_at: daysAgo(1), author: lite(mika)),
            Comment(id: "c-7", recipe_id: "seed-smash-tacos", user_id: theo.id, body: "Cast iron + a bacon press = perfect crust every time.", created_at: daysAgo(0.5), author: lite(theo)),
            Comment(id: "c-8", recipe_id: "seed-lemon-pasta", user_id: rafa.id, body: "Off-heat tip saved me — first attempt on heat went grainy, second was silk.", created_at: daysAgo(0.4), author: lite(rafa)),
            Comment(id: "c-9", recipe_id: "seed-breakfast-tacos", user_id: june.id, body: "The cottage cheese thing sounded wrong. It is extremely right.", created_at: daysAgo(0.3), author: lite(june)),
            Comment(id: "c-10", recipe_id: "seed-mushroom-ramen", user_id: mika.id, body: "Dry-pan mushroom sear is a game changer. Never crowding the pan again.", created_at: daysAgo(0.1), author: lite(mika)),
        ]
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
