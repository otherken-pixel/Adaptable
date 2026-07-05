import SwiftUI

enum SaveButtonVariant { case icon, bar }

/// Save-to-Cookbook toggle. Mirrors `src/components/SaveButton.tsx`.
struct SaveButtonView: View {
    let recipeId: String
    var variant: SaveButtonVariant = .icon

    @EnvironmentObject private var engagement: EngagementStore
    @EnvironmentObject private var authStore: AuthStore

    private var saved: Bool { engagement.savedIds.contains(recipeId) }

    var body: some View {
        switch variant {
        case .bar:
            Button(action: toggle) {
                HStack(spacing: 8) {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                    Text(saved ? "In your Cookbook" : "Save to Cookbook")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(saved ? Theme.accent : Theme.surface)
                .background(saved ? AnyShapeStyle(Theme.accentSoft) : AnyShapeStyle(Theme.content), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.pressable)
        case .icon:
            Button(action: toggle) {
                Image(systemName: saved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(saved ? Theme.accent : Theme.muted)
                    .frame(width: 40, height: 40)
                    .background(Theme.raised, in: Circle())
                    .overlay(Circle().stroke(Theme.line))
            }
            .buttonStyle(.pressable)
        }
    }

    private func toggle() {
        guard let userId = authStore.profile?.id else { return }
        engagement.toggleSaved(recipeId: recipeId, userId: userId)
    }
}
