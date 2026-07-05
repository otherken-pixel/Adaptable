import SwiftUI

/// Public recipe discussion. Mirrors `src/components/CommentsSection.tsx`.
struct CommentsSectionView: View {
    let recipeId: String

    @EnvironmentObject private var authStore: AuthStore
    @State private var comments: [Comment]?
    @State private var draft = ""
    @State private var posting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.fill").foregroundStyle(Theme.accent)
                Text("Comments").font(.system(size: 18, weight: .heavy))
                if let comments {
                    Text("\(comments.count)").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.faint)
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("How did it turn out? Tips, swaps, results…", text: $draft, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(1...4)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                Button {
                    Task { await post() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Theme.heroGradient, in: Circle())
                }
                .buttonStyle(.pressable)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || posting)
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.3 : 1)
                .padding(.trailing, 6).padding(.bottom, 6)
            }
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line))

            if comments == nil {
                SkeletonBlock(height: 64, cornerRadius: 16)
                SkeletonBlock(height: 64, cornerRadius: 16)
            } else if comments!.isEmpty {
                Text("No comments yet — cooked it? Tell everyone how it went. 👩‍🍳")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 24)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.line, style: StrokeStyle(dash: [4])))
            } else {
                VStack(spacing: 10) {
                    ForEach(comments!) { comment in
                        CommentRow(comment: comment, isOwn: authStore.profile?.id == comment.user_id) {
                            remove(comment.id)
                        }
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        comments = (try? await API.fetchComments(recipeId: recipeId)) ?? []
    }

    private func post() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let userId = authStore.profile?.id, !posting else { return }
        posting = true
        defer { posting = false }
        if let created = try? await API.addComment(userId: userId, recipeId: recipeId, body: body) {
            comments = [created] + (comments ?? [])
            draft = ""
        }
    }

    private func remove(_ id: String) {
        guard let userId = authStore.profile?.id else { return }
        comments = comments?.filter { $0.id != id }
        Task { try? await API.deleteComment(userId: userId, commentId: id) }
    }
}

private struct CommentRow: View {
    let comment: Comment
    let isOwn: Bool
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AuthorAvatar(username: comment.author?.username ?? comment.user_id, size: 26)
                Text(comment.author?.username ?? "anonymous").font(.system(size: 13, weight: .bold))
                Text(Format.timeAgo(comment.created_at)).font(.system(size: 12)).foregroundStyle(Theme.faint)
                Spacer()
                if isOwn {
                    Button(action: onDelete) {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Theme.faint)
                    }
                }
            }
            Text(comment.body).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
    }
}
