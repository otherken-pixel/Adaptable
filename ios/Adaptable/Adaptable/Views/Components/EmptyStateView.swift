import SwiftUI

struct EmptyStateView<Action: View>: View {
    let emoji: String
    let title: String
    let message: String
    @ViewBuilder var action: () -> Action

    init(emoji: String, title: String, message: String, @ViewBuilder action: @escaping () -> Action = { EmptyView() }) {
        self.emoji = emoji
        self.title = title
        self.message = message
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(emoji).font(.system(size: 56)).floating
            Text(title).font(.system(size: 17, weight: .bold))
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            action()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 64)
    }
}

/// Standard filled pill button used inside empty-state actions.
struct PillButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.surface)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(Theme.content))
        }
        .buttonStyle(.pressable)
    }
}
