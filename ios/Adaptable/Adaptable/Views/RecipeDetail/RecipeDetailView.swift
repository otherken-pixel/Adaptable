import SwiftUI

/// Mirrors `src/pages/RecipeDetailPage.tsx`.
struct RecipeDetailView: View {
    let recipeId: String

    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var engagement: EngagementStore
    @Environment(\.dismiss) private var dismiss

    @State private var recipe: Recipe??
    @State private var photos: [RecipePhoto] = []
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                content
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.surface)
        .navigationBarHidden(true)
        .task { await load() }
    }

    private func load() async {
        do {
            let r = try await API.fetchRecipe(id: recipeId)
            recipe = .some(r)
            photos = try await API.fetchRecipePhotos(recipeId: recipeId)
        } catch {
            print("[RecipeDetailView] Failed to load recipe \(recipeId): \(error)")
            // Non-404 errors (network, auth) show actual message
            // A 404 is expected — leave recipe as nil so "not found" UI shows
            errorMessage = error.localizedDescription
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            if case .some(.some(let r)) = recipe, let author = r.author {
                Text("by ").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
                    + Text(author.username ?? "anonymous").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.content)
            }
            Spacer()
            if case .some(.some(let r)) = recipe, r.author_id != authStore.profile?.id {
                let following = engagement.followedIds.contains(r.author_id ?? "")
                Button {
                    guard let userId = authStore.profile?.id else { return }
                    engagement.toggleFollowChef(chefId: r.author_id ?? "", userId: userId)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: following ? "checkmark" : "plus")
                        Text(following ? "Following" : "Follow").font(.system(size: 13, weight: .bold))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .foregroundStyle(following ? Theme.accent : Theme.surface)
                    .background(following ? AnyShapeStyle(Theme.accentSoft) : AnyShapeStyle(Theme.content), in: Capsule())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            EmptyStateView(emoji: "📡", title: "Connection hiccup", message: errorMessage) {
                PillButton(title: "Retry") { Task { await load() } }
             }
          } else if recipe == nil {
            VStack(alignment: .leading, spacing: 16) {
                SkeletonBlock(height: 220, cornerRadius: Theme.cardRadius)
                SkeletonBlock(height: 28, cornerRadius: 8).frame(maxWidth: 220)
                SkeletonBlock(height: 16, cornerRadius: 8)
                SkeletonBlock(height: 96, cornerRadius: Theme.cardRadius)
             }
          } else if recipe == .some(.none) {
            EmptyStateView(emoji: "🔍", title: "Recipe not found", message: "It may have been removed, or the link is off.") {
                PillButton(title: "Back to Discover") { dismiss() }
             }
          } else {
            // recipe == .some(.some(let r)) — show actual content
            VStack(alignment: .leading, spacing: 24) {
                if let r = recipe.flatMap({ $0 }) {
                    RecipeContentView(recipe: r)
                    if !photos.isEmpty {
                        communityPhotos
                     }
                    CommentsSectionView(recipeId: r.id)
                 }
              }
          }
      }

    private var communityPhotos: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("From the community's kitchens 📸").font(.system(size: 17, weight: .heavy))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(photos) { photo in
                        VStack(spacing: 4) {
                            if let url = photo.url, let u = URL(string: url) {
                                AsyncImage(url: u) { $0.resizable().scaledToFill() } placeholder: { Theme.sunken }
                                    .frame(width: 140, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line))
                            }
                            Text(Format.timeAgo(photo.created_at ?? "")).font(.system(size: 11)).foregroundStyle(Theme.faint)
                        }
                    }
                }
            }
        }
    }
}
