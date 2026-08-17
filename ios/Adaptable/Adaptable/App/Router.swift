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

struct CookSession: Identifiable, Equatable {
    let id: UUID
    let recipeId: String
    let servings: Int?

    init(recipeId: String, servings: Int?) {
        self.id = UUID()
        self.recipeId = recipeId
        self.servings = servings
    }
}

/// Cross-cutting navigation events: push taps, remix deep links, and
/// feed refresh signals after create/import success.
@MainActor
final class DeepLinkCenter: ObservableObject {
    @Published var activeTab: AppTab = .discover
    @Published var pendingRecipeId: String?
    @Published var remixRecipeId: String?
    @Published var feedTagFilter: String?
    @Published var pendingImportURL: String?
    @Published var pendingImportText: String?
    @Published var pendingCookRecipeId: String?
    @Published var cookbookRecipeId: String?
    @Published var createRecipeId: String?
    @Published var pendingPrep = false
    @Published var cookSession: CookSession?
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

    func openImport(url: String?, text: String?) {
        pendingImportURL = url
        pendingImportText = text
        activeTab = .create
    }

    func openCook(_ recipeId: String, servings: Int? = nil) {
        pendingCookRecipeId = nil
        cookSession = CookSession(recipeId: recipeId, servings: servings)
    }

    func openCookbookRecipe(_ id: String) {
        cookbookRecipeId = id
    }

    func openCreateRecipe(_ id: String) {
        createRecipeId = id
    }

    func openPrep() {
        pendingPrep = true
        activeTab = .create
    }
}

extension Notification.Name {
    static let cookCommand = Notification.Name("adaptable.cookCommand")
}
