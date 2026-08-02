import Foundation

struct ProfileLite: Codable, Equatable, Identifiable {
    var id: String
    var username: String?
    var avatar_url: String?
}

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

struct SeedChefEntry: Decodable { let username: String; let existing: Bool }
struct SeedCommentEntry: Decodable { let author: String; let body: String }
struct SeedRecipeEntry: Decodable {
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
struct SeedDataFile: Decodable { let chefs: [SeedChefEntry]; let recipes: [SeedRecipeEntry] }

let url = URL(fileURLWithPath: "/Users/kenmills/Developer/Adaptable/shared/seed-recipes.json")
do {
    let data = try Data(contentsOf: url)
    let decoded = try JSONDecoder().decode(SeedDataFile.self, from: data)
    print("Successfully decoded \(decoded.recipes.count) recipes")
} catch {
    print("Failed to decode: \(error)")
}
