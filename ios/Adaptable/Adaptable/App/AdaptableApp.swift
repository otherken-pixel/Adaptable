import SwiftUI

@main
struct AdaptableApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var authStore = AuthStore()
    @StateObject private var engagementStore = EngagementStore()
    @StateObject private var shoppingStore = ShoppingStore()
    @StateObject private var notificationsStore = NotificationsStore()
    @StateObject private var deepLinks = AppEnvironment.shared.deepLinks

    @State private var showResetPassword = false

    var body: some Scene {
        WindowGroup {
            RootView(showResetPassword: $showResetPassword)
                .environmentObject(authStore)
                .environmentObject(engagementStore)
                .environmentObject(shoppingStore)
                .environmentObject(notificationsStore)
                .environmentObject(deepLinks)
                .task {
                    authStore.start()
                    await PushManager.shared.refreshAuthorizationStatus()
                }
                .onOpenURL { url in
                    handle(url: url)
                }
        }
    }

    private func handle(url: URL) {
        guard url.scheme == "com.adaptable.app" else { return }
        if url.host == "reset-password" {
            Task {
                _ = try? await SupabaseManager.client.auth.session(from: url)
                showResetPassword = true
            }
        }
        // OAuth callbacks (login-callback) are consumed internally by the
        // ASWebAuthenticationSession that `signInWithOAuth` presents and
        // never reach here.
    }
}
