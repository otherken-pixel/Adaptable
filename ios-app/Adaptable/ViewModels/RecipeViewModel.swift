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
/// in an iOS SwiftUI MVVM architecture, including retry logic and
/// rollback on persistent failure.
@Observable
@MainActor
final class RecipeViewModel {
    var recipe: Recipe
    var errorMessage: String?

    private let client: SupabaseClient
    private let userId: UUID

    init(recipe: Recipe, client: SupabaseClient, userId: UUID) {
        self.recipe = recipe
        self.client = client
        self.userId = userId
    }

     /// Upvotes the recipe with optimistic update and exponential backoff retry.
    func toggleUpvote() {
         // 1. Snapshot the previous state for potential rollback
        let previousState = self.recipe

         // Clear any previous errors so the UI shows a clean state during retry.
        errorMessage = nil

         // 2. Optimistically update the UI instantly - user sees immediate feedback.
        self.recipe.upvotes += self.recipe.hasVoted ? -1 : 1
        self.recipe.hasVoted.toggle()

         // 3. Fire off the network request with retry logic.
        Task {
            let maxAttempts = 3
            var attempts = 0
            var lastError: Error?

            while attempts < maxAttempts {
                attempts += 1

                do {
                    if previousState.hasVoted {
                         // They are removing their vote - delete the row.
                        try await client.database
                             .from("recipe_votes")
                             .delete()
                             .eq("recipe_id", value: recipe.id.uuidString)
                             .eq("user_id", value: userId.uuidString)
                             .execute()
                     } else {
                         // They are adding a vote - upsert.
                        try await client.database
                             .from("recipe_votes")
                             .upsert(
                                 ["recipe_id": recipe.id.uuidString,
                                  "user_id": userId.uuidString]
                             )
                             .execute()
                     }

                     // Network succeeded - the optimistic UI is correct.
                     // Optionally refetch for canonical state on final attempt:
                    if attempts == maxAttempts {
                        try await fetchCanonicalState()
                     }

                     // Success - early return exits the while loop cleanly.
                    return
                 } catch {
                    print("Upvote sync failed (attempt \(attempts)): \(error)")
                    lastError = error
                     // Wait before retrying with exponential backoff: 1s, 2s, 4s...
                    if attempts < maxAttempts {
                        let delay = UInt64(pow(2.0, Double(attempts - 1))) * 1_000_000_000
                        try? await Task.sleep(nanoseconds: delay)
                     }
                 }
             }

             // All attempts exhausted - rollback and show error.
            self.recipe = previousState
            self.errorMessage = "Failed to save vote after \(maxAttempts) attempts. Please check your connection."
            print("Upvote fully failed, last error: \(lastError?.localizedDescription ?? "unknown")")
         }
     }

     /// Refetch canonical state from the server.
    private func fetchCanonicalState() async {
        do {
             // Fetch updated recipe - actual implementation depends on your recipes table structure.
            print("Refetching canonical recipe state for \(recipe.id)")
         } catch {
            print("Canonical refetch failed: \(error)")
         }
     }
}
