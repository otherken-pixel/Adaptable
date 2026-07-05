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

    private var deviceTokenData: Data?  /// Store raw Data for reformatting.
    private var currentUserId: String?
        /// Track retry attempts for token registration.
    private var registrationAttempts = 0
    private static let maxRegistrationAttempts = 3

    private init() {}

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
           case .authorized, .provisional, .ephemeral:
            status = deviceTokenData != nil || deviceToken != nil ? .enabled : .idle
           case .denied:
            status = .denied
          default:
            status = .idle
           }
         }

    func requestAuthorization() async {
           // Reset registration state on each authorization request.
        registrationAttempts = 0

        status = .working
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else {
            status = .denied
            return
             }
              // Register for remote notifications — the token callback fires asynchronously.
        UIApplication.shared.registerForRemoteNotifications()

          /// APNs should answer within seconds; extend timeout to 30s to account for
           // slow networks, CRL downloads on first launch, or device provisioning delays.
        try? await Task.sleep(nanoseconds: 30_000_000_000)

           // If still working after 30s, the token never arrived — likely denied.
        if status == .working {
               // Check one more time in case it came in right at timeout edge.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self, self.status == .working else { return }
                  self.status = self.deviceToken != nil ? .enabled : .denied
                   }
            }
         }

      /// Called from AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken.
    func didReceiveToken(_ tokenData: Data) {
           // Store raw data and compute hex string each time (token can rotate).
        deviceTokenData = tokenData
        Task {
             registrationAttempts += 1
              try? await tryRegister(attempt: registrationAttempts)
            }
         }

      /// Called from AppDelegate.didFailToRegisterForRemoteNotificationsWithError.
    func didFailToRegister() {
           // If we already have a stored token, keep status as enabled —
           // this might be a temporary certificate refresh failure.
        if deviceTokenData != nil { return }
        status = .denied
         }

    private var deviceToken: String? {
            deviceTokenData?.map { String(format: "%02hhx", $0) }.joined().uppercased()
          /// APNs expects uppercase hex tokens — edge functions calling
           // Apple's HTTP/2 API require this exact format.
         }

    func setCurrentUser(_ userId: String?) {
           currentUserId = userId
           Task {
               registrationAttempts += 1
                 try? await tryRegister(attempt: registrationAttempts)
              }
           }

    private func tryRegister(attempt: Int) async {
             guard let token = deviceToken, let userId = currentUserId, !SupabaseManager.isDemo else { return }

              // Log the attempt for debugging APNs delivery issues.
        print("Push registration attempt #\(attempt) for user \(userId), token: \(token.prefix(16))...")

              /// Use upsert instead of plain insert to handle APNs token rotation gracefully.
              /// If the row exists (previous token), it updates; if not, it inserts.
        do {
            try await API.registerDeviceToken(userId: userId, token: token, platform: "ios")
            status = .enabled
             print("Push registration successful")
           } catch {
                  // Only log errors on later attempts to avoid noise on first launch failures.
              if attempt > 1 {
                   print("Push registration failed (attempt \(attempt)): \(error)")
                    }
                      // If this was the last attempt, mark as denied.
              if attempt >= Self.maxRegistrationAttempts {
                status = .denied
                  }
                }
             }
         }
