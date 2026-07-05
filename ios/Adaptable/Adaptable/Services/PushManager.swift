import Foundation
import UIKit
import UserNotifications

/// Device push, 100% Supabase + Apple — no Firebase anywhere. iOS gets the
/// RAW APNs token (never routed through Firebase); it's stored in
/// `device_tokens` and the `push-dispatch` edge function delivers by
/// calling APNs directly. Mirrors `src/lib/push.ts`.
@MainActor
final class PushManager: ObservableObject {
    static let shared = PushManager()

    enum Status { case idle, working, enabled, denied, unsupported }

    @Published private(set) var status: Status = .idle

    private var deviceToken: String?
    private var currentUserId: String?

    private init() {}

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            status = deviceToken != nil ? .enabled : .idle
        case .denied:
            status = .denied
        default:
            status = .idle
        }
    }

    func requestAuthorization() async {
        status = .working
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else {
            status = .denied
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
        // Resolves to .enabled once didRegisterForRemoteNotificationsWithDeviceToken
        // fires and the token round-trips to Supabase; time out gracefully.
        try? await Task.sleep(nanoseconds: 15_000_000_000)
        if status == .working { status = .denied }
    }

    func didReceiveToken(_ tokenData: Data) {
        deviceToken = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        Task { await tryRegister() }
    }

    func didFailToRegister() {
        status = .denied
    }

    func setCurrentUser(_ userId: String?) {
        currentUserId = userId
        Task { await tryRegister() }
    }

    private func tryRegister() async {
        guard let token = deviceToken, let userId = currentUserId, !SupabaseManager.isDemo else { return }
        do {
            try await API.registerDeviceToken(userId: userId, token: token, platform: "ios")
            status = .enabled
        } catch {
            status = .denied
        }
    }
}
