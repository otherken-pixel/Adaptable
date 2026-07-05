import Foundation

/// Shared optimistic state for votes, saves and follows so every card,
/// detail page and the cookbook stay in sync instantly. Mirrors
/// `src/context/EngagementContext.tsx`.
@MainActor
final class EngagementStore: ObservableObject {
    @Published private(set) var votes: [String: VoteValue] = [:]
    @Published private(set) var savedIds: Set<String> = []
    @Published private(set) var followedIds: Set<String> = []
    /// Local net_upvote deltas from the user's own optimistic votes.
    @Published private(set) var voteDelta: [String: Int] = [:]

    private var loadedForProfileId: String?

    func load(for profile: Profile?) async {
        guard let profile else {
            votes = [:]; savedIds = []; followedIds = []; voteDelta = [:]
            loadedForProfileId = nil
            return
        }
        guard loadedForProfileId != profile.id else { return }
        loadedForProfileId = profile.id
        async let v = try? API.fetchMyVotes(userId: profile.id)
        async let s = try? API.fetchMySaveIds(userId: profile.id)
        async let f = try? API.fetchFollowees(userId: profile.id)
        let (votesResult, savesResult, followsResult) = await (v, s, f)
        votes = votesResult ?? [:]
        savedIds = Set(savesResult ?? [])
        followedIds = Set(followsResult ?? [])
    }

    func netUpvotes(recipeId: String, base: Int) -> Int {
        base + (voteDelta[recipeId] ?? 0)
    }

    func castVote(recipeId: String, value: VoteValue, userId: String) {
        let current = votes[recipeId] ?? 0
        let next: VoteValue? = current == value ? nil : value
        voteDelta[recipeId, default: 0] += -current + (next ?? 0)
        if let next { votes[recipeId] = next } else { votes.removeValue(forKey: recipeId) }

        Task {
            do {
                try await API.setVote(userId: userId, recipeId: recipeId, value: next)
            } catch {
                // Roll back on failure.
                voteDelta[recipeId, default: 0] += current - (next ?? 0)
                if current == 0 { votes.removeValue(forKey: recipeId) } else { votes[recipeId] = current }
            }
        }
    }

    func toggleSaved(recipeId: String, userId: String) {
        let wasSaved = savedIds.contains(recipeId)
        if wasSaved { savedIds.remove(recipeId) } else { savedIds.insert(recipeId) }

        Task {
            do {
                try await API.toggleSave(userId: userId, recipeId: recipeId, currentlySaved: wasSaved)
            } catch {
                if wasSaved { savedIds.insert(recipeId) } else { savedIds.remove(recipeId) }
            }
        }
    }

    func toggleFollowChef(chefId: String, userId: String) {
        guard chefId != userId else { return }
        let wasFollowing = followedIds.contains(chefId)
        if wasFollowing { followedIds.remove(chefId) } else { followedIds.insert(chefId) }

        Task {
            do {
                try await API.setFollow(userId: userId, chefId: chefId, follow: !wasFollowing)
            } catch {
                if wasFollowing { followedIds.insert(chefId) } else { followedIds.remove(chefId) }
            }
        }
    }
}
