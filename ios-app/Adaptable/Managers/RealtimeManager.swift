import Foundation
import Supabase
import SwiftUI
import Combine

/// Manages the lifecycle of Supabase Realtime connections,
/// ensuring sockets are closed in the background and re-opened in the foreground.
@Observable
final class RealtimeManager {
    static let shared = RealtimeManager()

     /// Per-user channel base — matches NotificationsStore and web's `supabase.channel("notifications:…")`.
    private static let channelPrefix = "notifications"

    private var isConnected = false
    private var channel: RealtimeChannel?
       /// The profile ID we're currently subscribed to (for cross-profile switching).
    private var subscribedProfileId: String?

    private init() {}

     /// Connect to the realtime channel for a specific user. Call this when
     /// the app becomes active or the profile changes.
    func connect(client: SupabaseClient, for profileId: String? = nil) async {
        guard !isConnected else { return }

         // If switching profiles, first disconnect from the old one.
        if let profileId {
            await disconnect(client: client)
            self.subscribedProfileId = nil
           }

          // Before connecting, fetch missed events via REST to catch up.
        await catchUpMissedEvents(client: client)

         channel = client.channel("\(Self.channelPrefix):\(profileId ?? "public")")

        let _ = channel?.on("postgres_changes", filter: .init(event: "INSERT", schema: "public", table: "notifications")) { message in
            print("Received new notification: \(message.payload)")
              // Dispatch update to UI via NotificationCenter or ObservableObject.
             }

        do {
            try await channel?.subscribe()
            isConnected = true
            if let profileId { self.subscribedProfileId = profileId }
            print("Successfully subscribed to Supabase Realtime")
           } catch {
            print("Failed to subscribe to Realtime: \(error)")
           }
       }

     /// Disconnect from the realtime channel. Call this when the app enters background.
    func disconnect(client: SupabaseClient) async {
        guard isConnected else { return }

        if let channel = channel {
            do {
                try await client.removeChannel(channel)
               } catch {
                print("Error removing channel: \(error)")
               }
           }

        channel = nil
        isConnected = false
        subscribedProfileId = nil
        print("Disconnected from Supabase Realtime")
       }

     /// Check if the app is currently in background (no foreground scenes).
    static func isAppBackgrounded() -> Bool {
        let activeScenes = UIApplication.shared.connectedScenes
             .filter { $0.activationState == .foregroundActive }
        return activeScenes.isEmpty
       }

     /// Catch up on missed notifications via REST while the socket was closed.
    private func catchUpMissedEvents(client: SupabaseClient) async {
          // Persist last sync timestamp to UserDefaults for persistence across lifecycle transitions.
        let lastSync = UserDefaults.standard.string(forKey: "lastNotificationsSync")
              ?? ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 0))
        let now = ISO8601DateFormatter().string(from: Date())

          print("Catch-up: fetching notifications since \(lastSync)")
           // Example (uncomment when schema matches):
           // let missed = try await client.database
           //       .from("notifications")
           //       .select()
           //       .gt("created_at", value: lastSync)
           //       .lt("created_at", value: now)
           //       .execute()
          // print("Caught up on \(missed.data.count) missed notifications")
         } catch {
          print("Catch-up fetch failed (non-fatal): \(error)")
         }
       }

     /// Mark the last sync timestamp after processing Realtime events.
    static func markSynced() {
        UserDefaults.standard.set(ISO8601DateFormatter().string(from: Date()),
                                   forKey: "lastNotificationsSync")
       }
}
