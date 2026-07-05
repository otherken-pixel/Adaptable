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

    func start(for profile: Profile?) async {
        guard let profile else {
            stop()
            items = []
            loadedForProfileId = nil
            return
        }
        guard loadedForProfileId != profile.id else { return }
        loadedForProfileId = profile.id
        stop()
        await refresh(userId: profile.id)

        if SupabaseManager.isDemo {
            demoUnsubscribe = DemoStore.shared.subscribe { [weak self] in
                Task { @MainActor in await self?.refresh(userId: profile.id) }
            }
        } else {
            realtimeTask = Task { [weak self] in
                guard let self else { return }
                let ch = SupabaseManager.client.channel("notifications:\(profile.id)")
                let changes = ch.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "notifications",
                    filter: "user_id=eq.\(profile.id)"
                )
                self.channel = ch
                await ch.subscribe()
                for await _ in changes {
                    await self.refresh(userId: profile.id)
                }
            }
        }
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
    }

    func markAllRead(userId: String) {
        items = items.map {
            var n = $0
            n.read = true
            return n
        }
        Task { try? await API.markNotificationsRead(userId: userId) }
    }
}
