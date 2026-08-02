import Foundation

/// Pure feed filter used by Discover. Mirrors the logic in
/// `src/lib/feedFilter.ts` / `src/pages/FeedPage.tsx` so chip behaviour
/// stays identical across clients.
enum FeedFilter {
    enum Chip: Equatable {
        case all
        case forYou
        case following
        case time(maxMinutes: Int)
        case calories(max: Int)
        case protein(min: Int)
        case tag(String)
    }

    static func apply(
        recipes: [Recipe],
        search: String,
        chip: Chip,
        dietTags: [String],
        followedAuthorIds: Set<String>
    ) -> [Recipe] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let diets = dietTags.map { $0.lowercased() }

        return recipes.filter { r in
            if !q.isEmpty {
                let haystack = (
                    [r.title ?? "", r.description ?? "", r.cuisine ?? ""] + (r.tags ?? [])
                )
                .joined(separator: " ")
                .lowercased()
                if !haystack.contains(q) { return false }
            }

            switch chip {
            case .all:
                return true
            case .time(let maxMinutes):
                return (r.prep_time_minutes ?? 0) + (r.cook_time_minutes ?? 0) <= maxMinutes
            case .calories(let max):
                // Recipes without calorie data can't claim to be low-cal.
                guard let calories = r.calories else { return false }
                return calories <= max
            case .protein(let min):
                if let protein = r.protein_g, protein >= min { return true }
                return (r.tags ?? []).contains { $0.lowercased() == "high-protein" }
            case .forYou:
                guard !diets.isEmpty else { return false }
                return (r.tags ?? []).contains { diets.contains($0.lowercased()) }
            case .following:
                guard let authorId = r.author_id, !authorId.isEmpty else { return false }
                return followedAuthorIds.contains(authorId)
            case .tag(let label):
                return (r.tags ?? []).contains { $0.lowercased() == label.lowercased() }
            }
        }
    }
}
