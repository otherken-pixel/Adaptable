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
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task {
                        await notificationsStore.resubscribeIfNeeded()
                    }
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
