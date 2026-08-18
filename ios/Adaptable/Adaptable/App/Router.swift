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
    /// Optional prompt applied when Cook Mode hands off to Remix.
    @Published var remixPrefill: String?
    @Published var feedTagFilter: String?
    @Published var pendingImportURL: String?
    @Published var pendingImportText: String?
    @Published var pendingCookRecipeId: String?
    @Published var pendingCookCommand: String?
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

    func openRemix(_ recipeId: String, prompt: String? = nil) {
        remixPrefill = prompt
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

    /// Open Cook Mode if needed, then deliver `next` / `timer` once the cook UI is up.
    func issueCookCommand(_ command: String, recipeId: String? = nil) {
        let id = recipeId
            ?? cookSession?.recipeId
            ?? CookLiveActivityController.currentRecipeId
            ?? KitchenSnapshot.tonight()?.recipeId
        if let id, cookSession?.recipeId != id {
            openCook(id)
        }
        pendingCookCommand = command
        NotificationCenter.default.post(name: .cookCommand, object: command)
    }

    func openCookbookRecipe(_ id: String) {
        activeTab = .cookbook
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
