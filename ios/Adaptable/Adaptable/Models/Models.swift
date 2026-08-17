import Foundation

/// Rows and shared shapes for the Supabase schema + Gemini output.
/// Mirrors `src/lib/types.ts` in the web app field-for-field so the two
/// clients stay wire-compatible against the same Postgres schema.

// MARK: - Preferences / Profile

struct LearnedTaste: Codable, Equatable {
    var cuisines: [String: Int] = [:]
    var proteins: [String: Int] = [:]
    var staples: [String] = []
    var spice_delta: Int = 0

    init(cuisines: [String: Int] = [:], proteins: [String: Int] = [:], staples: [String] = [], spice_delta: Int = 0) {
        self.cuisines = cuisines
        self.proteins = proteins
        self.staples = staples
        self.spice_delta = spice_delta
    }
}

struct Preferences: Codable, Equatable {
    var diets: [String]?
    var allergies: [String]?
    var dislikes: [String]?
    var household_size: Int?
    var spice: String?
    var skill: String?
    var learned: LearnedTaste?

    init(
        diets: [String]? = nil,
        allergies: [String]? = nil,
        dislikes: [String]? = nil,
        household_size: Int? = nil,
        spice: String? = nil,
        skill: String? = nil,
        learned: LearnedTaste? = nil
    ) {
        self.diets = diets
        self.allergies = allergies
        self.dislikes = dislikes
        self.household_size = household_size
        self.spice = spice
        self.skill = skill
        self.learned = learned
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
    var household_id: String? = nil
    var created_at: String?

    var lite: ProfileLite { ProfileLite(id: id, username: username, avatar_url: avatar_url) }
}

struct Household: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var invite_code: String
    var created_at: String?
}

struct HouseholdMember: Codable, Equatable {
    var household_id: String
    var user_id: String
    var role: String
    var username: String?
}

struct RecipeLineage: Codable, Equatable, Identifiable {
    var id: String
    var user_id: String
    var parent_recipe_id: String
    var child_recipe_id: String
    var leftover_focus: [String]
    var created_at: String
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
    /// AI-generated dish photo URL; nil falls back to emoji gradient.
    var image_url: String?
    var featured: Bool?
    var net_upvotes: Int?
    var cook_count: Int?
    var comment_count: Int?
    var created_at: String?
    var author: ProfileLite?
    /// Canonical staple-stripped tokens. Inferred client-side when missing.
    var ingredient_keys: [String]? = nil
    var primary_method: String? = nil
    var base_protein: String? = nil
    var meal_slot: String? = nil
    var active_prep_minutes: Int? = nil
    var equipment: [String]? = nil

    var totalMinutes: Int { (prep_time_minutes ?? 0) + (cook_time_minutes ?? 0) }
}

enum BundleKind: String, Codable, Equatable {
    case sharedBase = "shared_base"
    case concurrent
}

struct MealPrepBundle: Codable, Equatable, Identifiable {
    var id: String
    var kind: BundleKind
    var recipes: [Recipe]
    var headline: String
    var reason: String
    var shared_ingredients: [String]
    var session_minutes: Int
    var active_minutes: Int
    var avg_calories: Int?
    var generated_ids: [String]
    var missing_count: Int
    var leftover_focus: [String]

    var isComplete: Bool { missing_count == 0 && recipes.count >= 2 }

    init(
        id: String,
        kind: BundleKind,
        recipes: [Recipe],
        headline: String,
        reason: String,
        shared_ingredients: [String],
        session_minutes: Int,
        active_minutes: Int,
        avg_calories: Int?,
        generated_ids: [String],
        missing_count: Int,
        leftover_focus: [String]
    ) {
        self.id = id
        self.kind = kind
        self.recipes = recipes
        self.headline = headline
        self.reason = reason
        self.shared_ingredients = shared_ingredients
        self.session_minutes = session_minutes
        self.active_minutes = active_minutes
        self.avg_calories = avg_calories
        self.generated_ids = generated_ids
        self.missing_count = missing_count
        self.leftover_focus = leftover_focus
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(BundleKind.self, forKey: .kind)
        recipes = try c.decode([Recipe].self, forKey: .recipes)
        headline = try c.decode(String.self, forKey: .headline)
        reason = try c.decode(String.self, forKey: .reason)
        shared_ingredients = try c.decodeIfPresent([String].self, forKey: .shared_ingredients) ?? []
        session_minutes = try c.decodeIfPresent(Int.self, forKey: .session_minutes) ?? 0
        active_minutes = try c.decodeIfPresent(Int.self, forKey: .active_minutes) ?? 0
        avg_calories = try c.decodeIfPresent(Int.self, forKey: .avg_calories)
        generated_ids = try c.decodeIfPresent([String].self, forKey: .generated_ids) ?? []
        missing_count = try c.decodeIfPresent(Int.self, forKey: .missing_count) ?? 0
        leftover_focus = try c.decodeIfPresent([String].self, forKey: .leftover_focus) ?? []
    }
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
    var leftover_of: String? = nil
    var leftover_focus: String? = nil
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
    enum ErrorKind: Equatable {
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
        if !message.isEmpty {
            self.message = message
        } else {
            switch kind {
            case .noNetwork: self.message = "You're offline — check your connection."
            case .unauthorized: self.message = "Please sign in again."
            case .serverDown: self.message = "Server is unavailable — try again shortly."
            case .requestFailed(let detail): self.message = detail
            case .generic: self.message = "Something went wrong."
            }
        }
    }

    /// Convenience for call sites that only have user-facing copy.
    init(_ message: String) {
        self.kind = .generic
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
