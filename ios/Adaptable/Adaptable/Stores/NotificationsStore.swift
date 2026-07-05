import Foundation
import Supabase

/// Activity inbox: DB triggers write a row when someone votes, comments or
/// cooks your recipe; Supabase Realtime streams it in instantly. Mirrors
/// `src/context/NotificationsContext.tsx`.
@MainActor
final class NotificationsStore: ObservableObject {
     @Published private(set) var items: [AppNotification] = []

    var unreadCount: Int { items.filter { !$0.read }.count }

    private var loadedForProfileId: String?
    private var realtimeTask: Task<Void, Never>?
    private var demoUnsubscribe: (() -> Void)?
    private var channel: RealtimeChannelV2?
     /// Prevents duplicate start() calls during profile switching.
    private var isStarting = false

    func start(for profile: Profile?) async {
          // Guard against re-entrancy during profile switches.
        guard !isStarting else { return }
        isStarting = true

        guard let profile else {
            stop()
            items = []
            loadedForProfileId = nil
            isStarting = false
            return
           }

          // If already subscribed to this exact profile, nothing to do.
        guard loadedForProfileId != profile.id else {
            isStarting = false
            return
           }

          // If switching profiles, the `stop()` call below handles cleanup.
        loadedForProfileId = profile.id
        stop()
        await refresh(userId: profile.id)

        if SupabaseManager.isDemo {
            demoUnsubscribe = DemoStore.shared.subscribe { [weak self] in
                Task { @MainActor in await self?.refresh(userId: profile.id) }
             }
          } else {
              // Use a consistent channel naming pattern that matches RealtimeManager.
            let ch = SupabaseManager.client.channel("notifications:\(profile.id)")
            let changes = ch.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "notifications",
                filter: .eq("user_id", value: profile.id)
             )
            self.channel = ch
             // Use a cancellable task so we can detect cancellation cleanly.
            realtimeTask = Task { [weak self] in
                guard let self else { return }
                 do {
                     try await ch.subscribeWithError()
                   } catch {
                      print("Realtime subscription failed: \(error)")
                      return
                   }
                  for await _ in changes {
                       // Safely handle cancellation — stop the loop if task is cancelled.
                      guard !Task.isCancelled else { return }
                      await self.refresh(userId: profile.id)
                    }
                 } catch {
                    print("Realtime stream error: \(error)")
                  }
             }
           }

        isStarting = false
       }

    func stop() {
         realtimeTask?.cancel()
         realtimeTask = nil
         demoUnsubscribe?()
         demoUnsubscribe = nil

        if let channel {
            Task { await SupabaseManager.client.removeChannel(channel) }
           }
        channel = nil
       }

    func refresh(userId: String) async {
          items = (try? await API.fetchNotifications(userId: userId)) ?? []

          // Mark the sync timestamp after a successful fetch so catch-up
          // doesn't re-fetch already-seen events.
        UserDefaults.standard.set(ISO8601DateFormatter().string(from: Date()),
                                   forKey: "lastNotificationsSync")
       }

    func markAllRead(userId: String) {
        items = items.map {
            var n = $0
            n.read = true
            return n
           }
         Task { try? await API.markNotificationsRead(userId: userId) }
       }

     /// Re-fetch notifications for a new profile without full stop/start cycle.
      func refreshForNewProfile(userId: String) async {
          items = (try? await API.fetchNotifications(userId: userId)) ?? []
         UserDefaults.standard.set(ISO8601DateFormatter().string(from: Date()),
                                     forKey: "lastNotificationsSync")
       }
}
