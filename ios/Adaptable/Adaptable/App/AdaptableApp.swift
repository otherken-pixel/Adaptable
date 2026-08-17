import SwiftUI

@main
struct AdaptableApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var authStore = AuthStore()
    @StateObject private var engagementStore = EngagementStore()
    @StateObject private var shoppingStore = ShoppingStore()
    @StateObject private var notificationsStore = NotificationsStore()
    @StateObject private var deepLinks = AppEnvironment.shared.deepLinks
    @StateObject private var network = NetworkMonitor.shared

    @State private var showResetPassword = false

    var body: some Scene {
        WindowGroup {
            RootView(showResetPassword: $showResetPassword)
                .environmentObject(authStore)
                .environmentObject(engagementStore)
                .environmentObject(shoppingStore)
                .environmentObject(notificationsStore)
                .environmentObject(deepLinks)
                .environmentObject(network)
                .task {
                    authStore.start()
                    await PushManager.shared.refreshAuthorizationStatus()
                }
                .onOpenURL { url in
                    handle(url: url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        handle(url: url)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task {
                        await notificationsStore.resubscribeIfNeeded()
                    }
                    if let pending = KitchenSnapshot.consumePendingImport() {
                        deepLinks.openImport(url: pending.url, text: pending.text)
                    }
                }
        }
    }

    private func handle(url: URL) {
        // Universal Links / custom-scheme recipe deep links
        if let recipeId = SiteConfig.recipeId(from: url) {
            deepLinks.openRecipe(recipeId)
            return
        }

        if url.scheme == "com.adaptable.app", url.host == "cook" {
            let command = url.pathComponents.dropFirst().first ?? url.path
            if command == "next" || url.path.contains("next") {
                NotificationCenter.default.post(name: .cookCommand, object: "next")
            } else if command == "timer" || url.path.contains("timer") {
                NotificationCenter.default.post(name: .cookCommand, object: "timer")
            } else if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" })?.value {
                deepLinks.openCook(id)
            }
            return
        }
        if url.scheme == "com.adaptable.app", url.host == "import" {
            if let pending = KitchenSnapshot.consumePendingImport() {
                deepLinks.openImport(url: pending.url, text: pending.text)
            }
            return
        }
        if url.scheme == "com.adaptable.app", url.host == "recipe",
           let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "id" })?.value {
            deepLinks.openRecipe(id)
            return
        }

        guard url.scheme == "com.adaptable.app" else { return }
        if url.host == "reset-password" {
            Task {
                _ = try? await SupabaseManager.client.auth.session(from: url)
                showResetPassword = true
            }
        } else if url.host == "login-callback" {
            Task {
                do {
                    try await SupabaseManager.client.auth.session(from: url)
                } catch {
                    print("OAuth callback session exchange failed: \(error)")
                }
            }
        }
    }
}
