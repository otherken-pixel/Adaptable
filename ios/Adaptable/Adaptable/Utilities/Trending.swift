import Foundation

/// Hacker-News-style time-decayed heat score. Cooking a recipe is the
/// strongest signal (someone actually made it), then comments, then votes.
/// Mirrors `src/lib/trending.ts`.
enum Trending {
    static func score(_ recipe: Recipe, now: Date = Date()) -> Double {
        let created = ISODate.parse(recipe.created_at) ?? now
        let hours = max(0, now.timeIntervalSince(created) / 3600)
        let heat = Double(recipe.net_upvotes + 3 * recipe.cook_count + 2 * recipe.comment_count + 1)
        return heat / pow(hours + 2, 1.4)
    }

    static func sorted(_ rows: [Recipe]) -> [Recipe] {
        let now = Date()
        return rows.sorted { score($0, now: now) > score($1, now: now) }
    }
}
