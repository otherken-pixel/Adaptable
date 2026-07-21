import Foundation

/// Rows and shared shapes for the Supabase schema + Gemini output.
/// Mirrors `src/lib/types.ts` in the web app field-for-field so the two
/// clients stay wire-compatible against the same Postgres schema.

// MARK: - Preferences / Profile

struct Preferences: Codable, Equatable {
    var diets: [String]?
    var allergies: [String]?
    var dislikes: [String]?
    var household_size: Int?
    var spice: String?
    var skill: String?

    init(
        diets: [String]? = nil,
        allergies: [String]? = nil,
        dislikes: [String]? = nil,
        household_size: Int? = nil,
        spice: String? = nil,
        skill: String? = nil
    ) {
        self.diets = diets
        self.allergies = allergies
        self.dislikes = dislikes
        self.household_size = household_size
        self.spice = spice
        self.skill = skill
    }

    static let empty = Preferences()

    var summary: String {
        var bits: [String] = []
        if let diets, !diets.isEmpty { bits.append(diets.joined(separator: ", ")) }
        if let allergies, !allergies.isEmpty { bits.append("no " + allergies.joined(separator: ", ")) }
        if let household_size, household_size > 0 { bits.append("cooks for \(household_size)") }
        return bits.isEmpty ? "Diets, allergies, dislikes — the AI cooks around you" : bits.joined(separator: " · ")
    }
}

struct ProfileLite: Codable, Equatable, Identifiable {
    var id: String
    var username: String?
    var avatar_url: String?
}

struct Profile: Codable, Equatable, Identifiable {
    var id: String
    var username: String?
    var avatar_url: String?
    var preferences: Preferences?
    var created_at: String?

    var lite: ProfileLite { ProfileLite(id: id, username: username, avatar_url: avatar_url) }
}

// MARK: - Recipe

enum Difficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
}

struct Ingredient: Codable, Equatable, Identifiable {
    var item: String
    var quantity: String
    var note: String?

    var id: String { item + quantity }
}

struct RecipeStep: Codable, Equatable, Identifiable {
    var step: Int
    var instruction: String
    var tip: String?

    var id: Int { step }
}

struct Recipe: Codable, Equatable, Identifiable {
    var id: String
    var author_id: String?
    var title: String?
    var description: String?
    var emoji: String?
    var cuisine: String?
    var difficulty: Difficulty?
    var prep_time_minutes: Int?
    var cook_time_minutes: Int?
    var servings: Int?
    var calories: Int?
    var protein_g: Int?
    var carbs_g: Int?
    var fat_g: Int?
    var tags: [String]?
    var ingredients: [Ingredient]?
    var steps: [RecipeStep]?
    var source_prompt: String?
    var source_url: String?
    var net_upvotes: Int?
    var cook_count: Int?
    var comment_count: Int?
    var created_at: String?
    var author: ProfileLite?

    var totalMinutes: Int { (prep_time_minutes ?? 0) + (cook_time_minutes ?? 0) }
}

// MARK: - Comment

struct Comment: Codable, Equatable, Identifiable {
    var id: String
    var recipe_id: String?
    var user_id: String?
    var body: String?
    var created_at: String?
    var author: ProfileLite?
}

// MARK: - Votes / Feed

typealias VoteValue = Int // 1 or -1

enum FeedSort: String, CaseIterable {
    case hot, top, new
}

// MARK: - Meal plans

struct MealPlanEntry: Codable, Equatable, Identifiable {
    var id: String
    var user_id: String
    var recipe_id: String
    /// ISO date (yyyy-mm-dd)
    var plan_date: String
    var servings: Int
    var created_at: String
    var recipe: Recipe?
}

// MARK: - Recipe photos

struct RecipePhoto: Codable, Equatable, Identifiable {
    var id: String
    var recipe_id: String
    var user_id: String
    var path: String
    var created_at: String
    var url: String?
}

// MARK: - Notifications

enum NotificationKind: String, Codable {
    case vote, comment, cook
}

struct RecipeLite: Codable, Equatable {
    var id: String
    var title: String
    var emoji: String
}

struct AppNotification: Codable, Equatable, Identifiable {
    var id: String
    var user_id: String
    var actor_id: String?
    var recipe_id: String?
    var type: NotificationKind
    var read: Bool
    var created_at: String
    var actor: ProfileLite?
    var recipe: RecipeLite?
}

// MARK: - Shopping

struct ShoppingItem: Codable, Equatable, Identifiable {
    var id: String
    var recipe_id: String?
    var recipe_title: String
    var item: String
    var quantity: String
    var checked: Bool
    var created_at: String
}

// MARK: - Import source

struct ImportSource {
    var url: String?
    var text: String?
    var imageBase64: String?
    var mimeType: String?
}

// MARK: - App-level errors

struct AppError: LocalizedError, Equatable {
    enum ErrorKind {
        case noNetwork
        case unauthorized
        case serverDown
        case requestFailed(String)
        case generic
    }

    let kind: ErrorKind
    let message: String
    var errorDescription: String? { message }

    init(_ kind: ErrorKind, message: String = "") {
        self.kind = kind
        self.message = message
    }

    /// Maps a caught error to text safe to show a user. `AppError` carries
    /// copy we deliberately wrote (e.g. edge function messages), so it
    /// passes through verbatim; anything else — raw Postgrest/network/
    /// decoding errors — collapses to a generic message so backend
    /// internals (SQL, constraint names, HTTP plumbing) never leak into
    /// the UI. The original error is still printed to the console.
    static func friendlyMessage(for error: Error) -> String {
        if let appError = error as? AppError {
            return appError.message
        }
        return "Something went wrong — please check your connection and try again."
    }

    /// Helper to determine if an error is likely retryable (e.g., network timeout)
    var isRetryable: Bool {
        switch kind {
        case .noNetwork, .serverDown: return true
        default: return false
        }
    }
}
