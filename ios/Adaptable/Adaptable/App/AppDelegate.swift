import UIKit
import UserNotifications

/// Wires APNs registration and notification taps to `PushManager` and the
/// app's deep-link router. UIKit app-delegate hooks are still the most
/// reliable place for these callbacks even in a SwiftUI-lifecycle app.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in PushManager.shared.didReceiveToken(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in PushManager.shared.didFailToRegister() }
    }

    /// Foreground banners for notifications that arrive while the app is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    /// Tapping a push (recipe vote/comment/cook) deep-links to that recipe.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if let recipeId = response.notification.request.content.userInfo["recipe_id"] as? String {
            await MainActor.run { AppEnvironment.shared.deepLinks.openRecipe(recipeId) }
        }
    }
}

/// Small bridge so the UIKit AppDelegate can reach SwiftUI-owned singletons.
@MainActor
enum AppEnvironment {
    static let shared = Holder()

    @MainActor
    final class Holder {
        let deepLinks = DeepLinkCenter()
    }
}
