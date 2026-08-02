import SwiftUI

enum VotePillSize { case sm, lg }

/// Up/down voting pill with optimistic count, shared everywhere. Mirrors
/// `src/components/VotePill.tsx`.
struct VotePillView: View {
    let recipeId: String
    let baseCount: Int
    var size: VotePillSize = .sm

    @EnvironmentObject private var engagement: EngagementStore
    @EnvironmentObject private var authStore: AuthStore

    private var myVote: VoteValue { engagement.votes[recipeId] ?? 0 }
    private var iconSize: CGFloat { size == .lg ? 22 : 18 }
    private var pad: CGFloat { size == .lg ? 6 : 4 }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                cast(1)
            } label: {
                Image(systemName: myVote == 1 ? "arrowshape.up.fill" : "arrowshape.up")
                    .font(.system(size: iconSize))
                    .foregroundStyle(myVote == 1 ? Theme.up : Theme.muted)
                    .frame(width: 44, height: 44)
                    .background(myVote == 1 ? Theme.accentSoft : .clear, in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Upvote")
            .accessibilityAddTraits(myVote == 1 ? .isSelected : [])

            Text(Format.compactCount(engagement.netUpvotes(recipeId: recipeId, base: baseCount)))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(myVote == 1 ? Theme.up : myVote == -1 ? Theme.down : Theme.content)
                .frame(minWidth: 28)
                .monospacedDigit()
                .accessibilityLabel("\(engagement.netUpvotes(recipeId: recipeId, base: baseCount)) votes")

            Button {
                cast(-1)
            } label: {
                Image(systemName: myVote == -1 ? "arrowshape.down.fill" : "arrowshape.down")
                    .font(.system(size: iconSize))
                    .foregroundStyle(myVote == -1 ? Theme.down : Theme.muted)
                    .frame(width: 44, height: 44)
                    .background(myVote == -1 ? Theme.accentSoft : .clear, in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Downvote")
            .accessibilityAddTraits(myVote == -1 ? .isSelected : [])
        }
        .padding(pad)
        .background(Theme.raised, in: Capsule())
        .overlay(Capsule().stroke(Theme.line))
        .accessibilityElement(children: .contain)
    }

    private func cast(_ value: VoteValue) {
        guard let userId = authStore.profile?.id else { return }
        Haptics.selection()
        engagement.castVote(recipeId: recipeId, value: value, userId: userId)
    }
}
