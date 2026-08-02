import SwiftUI

/// AI dish photo when available; emoji + gradient fallback otherwise.
struct RecipeCoverView: View {
    let recipeId: String
    var emoji: String?
    var imageUrl: String?
    var cuisine: String?
    var height: CGFloat = 176
    var emojiSize: CGFloat = 64

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallback
                    case .empty:
                        Gradients.cover(for: recipeId)
                            .overlay(ProgressView().tint(.white))
                    @unknown default:
                        fallback
                    }
                }
                LinearGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            } else {
                fallback
            }

            if let cuisine, !cuisine.isEmpty {
                Text(cuisine)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.black.opacity(0.4), in: Capsule())
                    .padding(12)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var fallback: some View {
        ZStack {
            Gradients.cover(for: recipeId)
            Text(emoji ?? "🍳")
                .font(.system(size: emojiSize))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 8)
                .floating
        }
    }
}
