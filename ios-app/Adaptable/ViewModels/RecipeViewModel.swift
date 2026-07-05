import Foundation
import Supabase
import SwiftUI

struct Recipe: Identifiable, Codable {
    let id: UUID
    var title: String
    var upvotes: Int
    var hasVoted: Bool
}

/// A ViewModel demonstrating best practices for Optimistic UI updates
/// in an iOS SwiftUI MVVM architecture.
@Observable
@MainActor
final class RecipeViewModel {
    var recipe: Recipe
    var errorMessage: String?
    
    // Assuming a globally configured Supabase client
    // let client = SupabaseClient(...)
    
    init(recipe: Recipe) {
        self.recipe = recipe
    }
    
    /// Upvotes the recipe, instantly updating the UI and gracefully rolling back on failure.
    func toggleUpvote(client: SupabaseClient, userId: UUID) {
        // 1. Snapshot the previous state
        let previousState = self.recipe
        
        // 2. Optimistically update the UI instantly
        self.recipe.upvotes += self.recipe.hasVoted ? -1 : 1
        self.recipe.hasVoted.toggle()
        
        // Clear any previous errors
        self.errorMessage = nil
        
        // 3. Fire off the network request in the background
        Task {
            do {
                if previousState.hasVoted {
                    // They are removing their vote
                    try await client.database
                        .from("recipe_votes")
                        .delete()
                        .eq("recipe_id", value: recipe.id)
                        .eq("user_id", value: userId)
                        .execute()
                } else {
                    // They are adding a vote
                    try await client.database
                        .from("recipe_votes")
                        .insert(["recipe_id": recipe.id.uuidString, "user_id": userId.uuidString])
                        .execute()
                }
                
                // Network succeeded, the optimistic UI is correct.
                // You could optionally refetch the canonical state here if needed.
                
            } catch {
                // 4. If the network fails, roll back to the snapshot
                print("Failed to sync upvote: \(error)")
                self.recipe = previousState
                self.errorMessage = "Failed to save vote. Please check your connection."
            }
        }
    }
}
