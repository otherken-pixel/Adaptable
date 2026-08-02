import Foundation
import Supabase
import UIKit

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
    private var isStarting = false
    private var foregroundObserver: NSObjectProtocol?

    init() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.resubscribeIfNeeded()
            }
        }
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    func start(for profile: Profile?) async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        guard let profile else {
            stop()
            items = []
            loadedForProfileId = nil
            return
        }

        // Same profile: just refresh, keep subscription.
        if loadedForProfileId == profile.id {
            await refresh(userId: profile.id)
            return
        }

        loadedForProfileId = profile.id
        stopSubscriptionOnly()
        await refresh(userId: profile.id)
        await subscribe(userId: profile.id)
    }

    /// Re-fetch + re-subscribe after returning from background.
    func resubscribeIfNeeded() async {
        guard let userId = loadedForProfileId else { return }
        await refresh(userId: userId)
        if !SupabaseManager.isDemo, channel == nil {
            await subscribe(userId: userId)
        }
    }

    private func subscribe(userId: String) async {
        if SupabaseManager.isDemo {
            demoUnsubscribe = DemoStore.shared.subscribe { [weak self] in
                Task { @MainActor in await self?.refresh(userId: userId) }
            }
            return
        }

        let ch = SupabaseManager.client.channel("notifications:\(userId)")
        let changes = ch.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "notifications",
            filter: .eq("user_id", value: userId)
        )
        self.channel = ch
        realtimeTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await ch.subscribeWithError()
            } catch {
                print("[NotificationsStore] Realtime subscription failed: \(error)")
                await MainActor.run { self.channel = nil }
                return
            }
            for await _ in changes {
                guard !Task.isCancelled else { return }
                await self.refresh(userId: userId)
            }
        }
    }

    private func stopSubscriptionOnly() {
        realtimeTask?.cancel()
        realtimeTask = nil
        demoUnsubscribe?()
        demoUnsubscribe = nil
        if let channel {
            let ch = channel
            Task { await SupabaseManager.client.removeChannel(ch) }
        }
        channel = nil
    }

    func stop() {
        stopSubscriptionOnly()
    }

    func refresh(userId: String) async {
        items = (try? await API.fetchNotifications(userId: userId)) ?? items
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
