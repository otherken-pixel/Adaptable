import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var engagementStore: EngagementStore
    @EnvironmentObject private var shoppingStore: ShoppingStore
    @EnvironmentObject private var notificationsStore: NotificationsStore
    @Binding var showResetPassword: Bool

    var body: some View {
        Group {
            if authStore.loading {
                SplashView()
            } else if authStore.profile == nil {
                AuthView()
            } else {
                MainTabView()
            }
        }
        .fullScreenCover(isPresented: $showResetPassword) {
            ResetPasswordView(isPresented: $showResetPassword)
        }
        .task(id: authStore.profile?.id) {
            await engagementStore.load(for: authStore.profile)
            await shoppingStore.load(for: authStore.profile)
            await notificationsStore.start(for: authStore.profile)
            PushManager.shared.setCurrentUser(authStore.profile?.id)
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.heroGradient)
                .frame(width: 64, height: 64)
                .shadow(color: Theme.accent.opacity(0.25), radius: 20, y: 8)
                .overlay(Image(systemName: "fork.knife").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white))
                .floating
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var shoppingStore: ShoppingStore
    @EnvironmentObject private var deepLinks: DeepLinkCenter
    @EnvironmentObject private var authStore: AuthStore

    @State private var discoverPath = NavigationPath()
    @State private var cookbookPath = NavigationPath()
    @State private var createPath = NavigationPath()
    @State private var groceriesPath = NavigationPath()
    @State private var profilePath = NavigationPath()

    var body: some View {
        TabView(selection: $deepLinks.activeTab) {
            NavigationStack(path: $discoverPath) {
                FeedView()
                    .navigationDestination(for: Route.self, destination: routeDestination)
            }
            .tabItem { Label("Discover", systemImage: "flame.fill") }
            .tag(AppTab.discover)

            NavigationStack(path: $cookbookPath) {
                CookbookView()
                    .navigationDestination(for: Route.self, destination: routeDestination)
            }
            .tabItem { Label("Cookbook", systemImage: "bookmark.fill") }
            .tag(AppTab.cookbook)

            NavigationStack(path: $createPath) {
                GenerateView()
                    .navigationDestination(for: Route.self, destination: routeDestination)
            }
            .tabItem { Label("Create", systemImage: "sparkles") }
            .tag(AppTab.create)

            NavigationStack(path: $groceriesPath) {
                ShoppingListView()
                    .navigationDestination(for: Route.self, destination: routeDestination)
            }
            .tabItem { Label("Groceries", systemImage: "basket.fill") }
            .badge(shoppingStore.uncheckedCount)
            .tag(AppTab.groceries)

            NavigationStack(path: $profilePath) {
                ProfileView()
                    .navigationDestination(for: Route.self, destination: routeDestination)
            }
            .tabItem { Label("You", systemImage: "person.crop.circle.fill") }
            .tag(AppTab.profile)
        }
        .tint(Theme.accent)
        .onChange(of: deepLinks.pendingRecipeId) { _, id in
            guard let id else { return }
            discoverPath.append(Route.recipe(id: id))
            deepLinks.pendingRecipeId = nil
        }
    }

    @ViewBuilder
    private func routeDestination(_ route: Route) -> some View {
        switch route {
        case .recipe(let id):
            RecipeDetailView(recipeId: id)
        case .cookMode(let id, let servings):
            CookModeView(recipeId: id, servings: servings)
        case .tasteProfile:
            TasteProfileView()
        case .activity:
            ActivityView()
        }
    }
}
