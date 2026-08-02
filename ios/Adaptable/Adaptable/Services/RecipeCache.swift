import Foundation

/// Lightweight disk cache for feed + recently opened recipes.
/// Speeds cold opens and supports offline re-open of known recipes.
enum RecipeCache {
    private static let feedKey = "adaptable.cache.feed.v1"
    private static let recipePrefix = "adaptable.cache.recipe.v1."
    private static let maxRecipes = 40

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    private static let decoder = JSONDecoder()

    static func saveFeed(_ recipes: [Recipe]) {
        guard let data = try? encoder.encode(recipes) else { return }
        UserDefaults.standard.set(data, forKey: feedKey)
    }

    static func loadFeed() -> [Recipe]? {
        guard let data = UserDefaults.standard.data(forKey: feedKey) else { return nil }
        return try? decoder.decode([Recipe].self, from: data)
    }

    static func saveRecipe(_ recipe: Recipe) {
        guard let data = try? encoder.encode(recipe) else { return }
        UserDefaults.standard.set(data, forKey: recipePrefix + recipe.id)
        prune()
    }

    static func loadRecipe(id: String) -> Recipe? {
        guard let data = UserDefaults.standard.data(forKey: recipePrefix + id) else { return nil }
        return try? decoder.decode(Recipe.self, from: data)
    }

    private static func prune() {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(recipePrefix) }
        guard keys.count > maxRecipes else { return }
        // Drop arbitrary excess — recipes are re-fetched when online.
        for key in keys.prefix(keys.count - maxRecipes) {
            defaults.removeObject(forKey: key)
        }
    }
}
