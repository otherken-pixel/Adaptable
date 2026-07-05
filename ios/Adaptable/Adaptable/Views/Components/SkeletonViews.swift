import SwiftUI

/// Shimmering placeholder block used while content loads.
struct SkeletonBlock: View {
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 10
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.sunken)
            .frame(height: height)
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.35), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .rotationEffect(.degrees(20))
                .offset(x: phase * 260)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

struct RecipeCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBlock(height: 176, cornerRadius: 0)
            VStack(alignment: .leading, spacing: 12) {
                SkeletonBlock(height: 20, cornerRadius: 8).frame(maxWidth: 220)
                SkeletonBlock(height: 16, cornerRadius: 8)
                HStack(spacing: 8) {
                    SkeletonBlock(height: 24, cornerRadius: 12).frame(width: 64)
                    SkeletonBlock(height: 24, cornerRadius: 12).frame(width: 56)
                    SkeletonBlock(height: 24, cornerRadius: 12).frame(width: 72)
                }
            }
            .padding(16)
        }
        .background(Theme.raised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

struct FeedSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            RecipeCardSkeleton()
            RecipeCardSkeleton()
            RecipeCardSkeleton()
        }
    }
}
