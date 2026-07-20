import Foundation
import SwiftUI

/// Navigation destinations pushed onto a tab's `NavigationStack`.
enum Route: Hashable {
    case recipe(id: String)
    case cookMode(id: String, servings: Int?)
    case tasteProfile
    case activity
}

enum AppTab: Hashable {
    case discover, cookbook, create, groceries, profile
}

/// Cross-cutting navigation events: push taps, remix deep links, and
/// feed refresh signals after create/import success.
@MainActor
final class DeepLinkCenter: ObservableObject {
    @Published var activeTab: AppTab = .discover
    @Published var pendingRecipeId: String?
    @Published var remixRecipeId: String?
    @Published var feedTagFilter: String?
    /// Bump to force Discover (and similar lists) to reload.
    @Published private(set) var feedRefreshToken = UUID()

    func openRecipe(_ id: String) {
        activeTab = .discover
        pendingRecipeId = id
    }

    func openRemix(_ recipeId: String) {
        remixRecipeId = recipeId
        activeTab = .create
    }

    func openFeed(tag: String) {
        activeTab = .discover
        feedTagFilter = tag
    }

    func requestFeedRefresh() {
        feedRefreshToken = UUID()
    }
}
