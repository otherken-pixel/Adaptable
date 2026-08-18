import SwiftUI

/// Feed/Cookbook/Profile recipe card. Mirrors `src/components/RecipeCard.tsx`.
struct RecipeCardView: View {
    let recipe: Recipe
    var index: Int = 0
    /// Discover/Profile can use the implicit link. Cookbook must not —
    /// appearing/disappearing links auto-push a recipe when the parent list changes.
    var asLink: Bool = true

    var body: some View {
        Group {
            if asLink {
                NavigationLink(value: Route.recipe(id: recipe.id)) { card }
            } else {
                card
            }
        }
        .buttonStyle(.plain)
        .fadeUpAppear(index: index)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    RecipeCoverView(
                        recipeId: recipe.id,
                        emoji: recipe.emoji,
                        imageUrl: recipe.image_url,
                        cuisine: recipe.cuisine,
                        height: 176,
                        emojiSize: 64
                    )
                    SaveButtonView(recipeId: recipe.id)
                        .padding(12)
                }

                // Body
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title ?? "")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.content)
                        Text(recipe.description ?? "")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        MetaPill(icon: "clock", label: Format.totalMinutes(prep: recipe.prep_time_minutes ?? 0, cook: recipe.cook_time_minutes ?? 0))
                        MetaPill(icon: "gauge.medium", label: recipe.difficulty?.rawValue ?? "")
                        if let cal = recipe.calories {
                            MetaPill(icon: "flame", label: "\(cal) cal")
                        }
                        if (recipe.cook_count ?? 0) > 0 {
                            MetaPill(icon: "flame.fill", label: "\(Format.compactCount(recipe.cook_count ?? 0)) cooked", accent: true)
                        }
                        if (recipe.comment_count ?? 0) > 0 {
                            MetaPill(icon: "bubble.left", label: Format.compactCount(recipe.comment_count ?? 0))
                        }
                    }
                    .lineLimit(1)

                    Divider().overlay(Theme.line)

                    HStack {
                        HStack(spacing: 8) {
                            AuthorAvatar(username: recipe.author?.username ?? recipe.author_id ?? "anonymous", size: 28)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(recipe.author?.username ?? "anonymous")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(Format.timeAgo(recipe.created_at ?? ""))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.faint)
                            }
                        }
                        Spacer()
                        VotePillView(recipeId: recipe.id, baseCount: recipe.net_upvotes ?? 0)
                    }
                }
                .padding(16)
            }
            .background(Theme.raised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
            .shadow(color: .black.opacity(0.05), radius: 16, y: 2)
    }
}

struct MetaPill: View {
    let icon: String
    let label: String
    var accent: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11))
            Text(label).font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .foregroundStyle(accent ? Theme.accent : Theme.muted)
        .background(accent ? Theme.accentSoft : Theme.sunken, in: Capsule())
    }
}

struct AuthorAvatar: View {
    let username: String
    var size: CGFloat = 28
    var url: String? = nil

    var body: some View {
        Group {
            if let url, let u = URL(string: url) {
                AsyncImage(url: u) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialCircle
                }
            } else {
                initialCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialCircle: some View {
        Gradients.cover(for: username)
            .overlay(
                Text(username.prefix(1).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}
