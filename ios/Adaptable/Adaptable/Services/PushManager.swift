import Foundation
import UIKit
import UserNotifications

/// Device push via raw APNs + Supabase `device_tokens` / `push-dispatch`.
/// No Firebase. Mirrors `src/lib/push.ts`.
@MainActor
final class PushManager: ObservableObject {
    static let shared = PushManager()

    enum Status { case idle, working, enabled, denied, unsupported }

    @Published private(set) var status: Status = .idle

    private var deviceTokenData: Data?
    private var currentUserId: String?
    private var registrationAttempts = 0
    private static let maxRegistrationAttempts = 3
    private var timeoutTask: Task<Void, Never>?

    private init() {}

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            status = deviceTokenData != nil ? .enabled : .idle
        case .denied:
            status = .denied
        default:
            status = .idle
        }
    }

    func requestAuthorization() async {
        registrationAttempts = 0
        timeoutTask?.cancel()
        status = .working

        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else {
            status = .denied
            return
        }

        UIApplication.shared.registerForRemoteNotifications()

        // If APNs never answers, leave working state after a bounded wait.
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard let self, !Task.isCancelled else { return }
            if self.status == .working {
                self.status = self.deviceTokenData != nil ? .enabled : .denied
            }
        }
    }

    func didReceiveToken(_ tokenData: Data) {
        deviceTokenData = tokenData
        timeoutTask?.cancel()
        Task {
            registrationAttempts += 1
            await tryRegister(attempt: registrationAttempts)
        }
    }

    func didFailToRegister() {
        timeoutTask?.cancel()
        if deviceTokenData != nil { return }
        status = .denied
    }

    private var deviceToken: String? {
        // Apple accepts either case; uppercase matches many server examples.
        deviceTokenData?.map { String(format: "%02hhx", $0) }.joined().uppercased()
    }

    func setCurrentUser(_ userId: String?) {
        let previous = currentUserId
        currentUserId = userId

        // On sign-out, drop this device token so the next account doesn't
        // inherit pushes for the previous user.
        if userId == nil, let previous, let token = deviceToken, !SupabaseManager.isDemo {
            Task {
                try? await API.unregisterDeviceToken(userId: previous, token: token)
            }
            return
        }

        guard userId != nil else { return }
        Task {
            registrationAttempts = 1
            await tryRegister(attempt: 1)
        }
    }

    private func tryRegister(attempt: Int) async {
        guard let token = deviceToken, let userId = currentUserId, !SupabaseManager.isDemo else { return }
        print("[Push] registration attempt #\(attempt) user=\(userId) token=\(token.prefix(16))…")
        do {
            try await API.registerDeviceToken(userId: userId, token: token, platform: "ios")
            status = .enabled
            print("[Push] registration successful")
        } catch {
            if attempt > 1 {
                print("[Push] registration failed (attempt \(attempt)): \(error)")
            }
            if attempt >= Self.maxRegistrationAttempts {
                // Keep idle rather than "denied" — system permission may still be OK.
                if status == .working { status = .idle }
            } else {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_500_000_000)
                guard currentUserId == userId else { return }
                registrationAttempts = attempt + 1
                await tryRegister(attempt: attempt + 1)
            }
        }
    }
}
