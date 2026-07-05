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

/// Cross-cutting navigation events: push-notification taps, and remix
/// deep links from the Recipe view into the Create tab.
@MainActor
final class DeepLinkCenter: ObservableObject {
    @Published var activeTab: AppTab = .discover
    @Published var pendingRecipeId: String?
    @Published var remixRecipeId: String?
    @Published var feedTagFilter: String?

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
}
