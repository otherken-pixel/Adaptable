import Foundation

/// Hacker-News-style time-decayed heat score. Cooking a recipe is the
/// strongest signal (someone actually made it), then comments, then votes.
/// Mirrors `src/lib/trending.ts`.
enum Trending {
    static func score(_ recipe: Recipe, now: Date = Date()) -> Double {
        let created = ISODate.parse(recipe.created_at ?? "") ?? now
        let hours = max(0, now.timeIntervalSince(created) / 3600)
        let upvotes = recipe.net_upvotes ?? 0
        let cooks = recipe.cook_count ?? 0
        let comments = recipe.comment_count ?? 0
        let heat = Double(upvotes + 3 * cooks + 2 * comments + 1)
        return heat / pow(hours + 2, 1.4)
    }

    static func sorted(_ rows: [Recipe]) -> [Recipe] {
        let now = Date()
        return rows.sorted { score($0, now: now) > score($1, now: now) }
    }
}
