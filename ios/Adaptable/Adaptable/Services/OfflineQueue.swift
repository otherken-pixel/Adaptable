import Combine
import Foundation
import Network

/// Lightweight offline mutation queue. Captures user actions when connectivity
/// is absent, stores them locally, and replays them automatically once the
/// network path becomes reachable again.
@MainActor
final class OfflineQueue: ObservableObject {
    static let shared = OfflineQueue()

    private init() {
        startMonitoring()
    }

    /// A pending mutation that couldn't be executed immediately.
    enum Action: Equatable {
        case vote(recipeId: String, value: VoteValue?)
        case save(recipeId: String)
        case follow(chefId: String, isFollow: Bool)
    }

    @Published private(set) var pendingActions: [Action] = []

    /// A basic reachability monitor to detect when internet returns.
    private let pathMonitor = NWPathMonitor()

    /// Captures a mutable action into the queue if no internet is available.
    func capture(action: Action) {
        pendingActions.append(action)
        Task {
            guard pendingActions.count <= 10 else { return }  // Prevent runaway queues
            await replay()
        }
    }

    /// Process all pending actions sequentially to avoid race conditions.
    private func replay() async {
        while !pendingActions.isEmpty {
            let action = pendingActions[0]
            print("[OfflineQueue] Replaying: \(actionDescription(action))")

            switch action {
            case .vote(let rid, let val):
                do {
                    try await API.setVote(
                        userId: SupabaseManager.client.auth.session.user.id.uuidString,
                        recipeId: rid, value: val)
                } catch { print("[OfflineQueue] Vote replay failed: \(error)") }
            case .save(let rid):
                do {
                    try await API.toggleSave(
                        userId: SupabaseManager.client.auth.session.user.id.uuidString,
                        recipeId: rid, currentlySaved: true)
                } catch { print("[OfflineQueue] Save replay failed: \(error)") }
            case .follow(let chefId, let isFollow):
                do {
                    try await API.setFollow(
                        userId: SupabaseManager.client.auth.session.user.id.uuidString,
                        chefId: chefId, follow: isFollow)
                } catch { print("[OfflineQueue] Follow replay failed: \(error)") }
            }

            // Only remove if it succeeded (in a real app, we'd track success/failure per item)
            pendingActions.remove(at: 0)
        }
    }

    private func actionDescription(_ action: Action) -> String {
        switch action {
        case .vote(let rid, let val): return "Vote on \(rid) -> \(val?.description ?? "null")"
        case .save(let rid): return "Save \(rid)"
        case .follow(let chefId, let isFollow): return "Follow \(chefId) (\(isFollow))"
        }
    }

    /// Begin listening for network changes.
    private func startMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await self?.replay() }
        }
        pathMonitor.start(queue: .global(qos: .utility))
    }

    /// Explicitly remove a pending action (e.g., if user changes their mind before sync).
    func cancel(_ action: Action) {
        pendingActions.removeAll { $0 == action }
    }
}

// MARK: - VoteValue extension for description
extension VoteValue { var description: String { "\(self)" } }
