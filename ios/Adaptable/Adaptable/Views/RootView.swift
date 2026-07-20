import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var engagementStore: EngagementStore
    @EnvironmentObject private var shoppingStore: ShoppingStore
    @EnvironmentObject private var notificationsStore: NotificationsStore
    @EnvironmentObject private var network: NetworkMonitor
    @Binding var showResetPassword: Bool

    var body: some View {
        Group {
            if authStore.loading {
                SplashView()
            } else if authStore.profile == nil && !authStore.hasSession {
                AuthView()
            } else if authStore.profile == nil, authStore.hasSession {
                // Soft-fail: session exists but profile fetch failed.
                ProfileLoadErrorView()
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
        .overlay(alignment: .top) {
            if !network.isOnline {
                OfflineBanner()
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: network.isOnline)
        .overlay(alignment: .bottom) {
            if let message = engagementStore.lastActionError {
                ActionToast(message: message) {
                    engagementStore.lastActionError = nil
                }
                .padding(.bottom, 88)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: message) {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if engagementStore.lastActionError == message {
                        engagementStore.lastActionError = nil
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: engagementStore.lastActionError)
    }
}

private struct OfflineBanner: View {
    var body: some View {
        Text("You're offline — some actions are paused")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.content.opacity(0.92), in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
}

private struct ActionToast: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.down.opacity(0.95), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }
}

private struct ProfileLoadErrorView: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        VStack(spacing: 16) {
            Text("📡").font(.system(size: 48))
            Text("Couldn't load your kitchen")
                .font(.system(size: 20, weight: .heavy))
            Text(authStore.profileLoadError ?? "Check your connection and try again.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            PillButton(title: "Retry") {
                Task { await authStore.retryProfileLoad() }
            }
            Button("Sign out") {
                Task { await authStore.signOut() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface.ignoresSafeArea())
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
            deepLinks.activeTab = .discover
            discoverPath.append(Route.recipe(id: id))
            deepLinks.pendingRecipeId = nil
        }
        .onChange(of: deepLinks.activeTab) { _, tab in
            // Returning to Discover after Create should pick up new recipes.
            if tab == .discover {
                deepLinks.requestFeedRefresh()
            }
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
