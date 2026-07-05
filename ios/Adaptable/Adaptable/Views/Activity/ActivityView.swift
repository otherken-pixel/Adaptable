import SwiftUI

/// Notification inbox. Mirrors `src/pages/ActivityPage.tsx`.
struct ActivityView: View {
    @EnvironmentObject private var notificationsStore: NotificationsStore
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if notificationsStore.items.isEmpty {
                    EmptyStateView(emoji: "🔔", title: "No activity yet", message: "Publish a recipe and you'll hear it here the moment someone upvotes, comments or cooks it.")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(notificationsStore.items.enumerated()), id: \.element.id) { i, n in
                            NotificationRow(notification: n).fadeUpAppear(index: i, unit: 0.045)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.surface)
        .navigationBarHidden(true)
        .onAppear {
            guard notificationsStore.unreadCount > 0, let userId = authStore.profile?.id else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                notificationsStore.markAllRead(userId: userId)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(notificationsStore.unreadCount > 0 ? "\(notificationsStore.unreadCount) NEW" : "ALL CAUGHT UP")
                    .font(.system(size: 12, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.accent)
                Text("Activity").font(.system(size: 32, weight: .heavy))
            }
            Spacer()
            if notificationsStore.unreadCount > 0 {
                Button {
                    guard let userId = authStore.profile?.id else { return }
                    notificationsStore.markAllRead(userId: userId)
                } label: {
                    Label("Mark read", systemImage: "checkmark.circle").font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .foregroundStyle(Theme.muted)
                        .background(Theme.sunken, in: Capsule())
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
    }
}

private struct NotificationRow: View {
    let notification: AppNotification

    private var icon: String {
        switch notification.type {
        case .vote: return "arrowshape.up.fill"
        case .comment: return "bubble.left.fill"
        case .cook: return "flame.fill"
        }
    }

    private var verb: String {
        switch notification.type {
        case .vote: return "upvoted"
        case .comment: return "commented on"
        case .cook: return "just cooked"
        }
    }

    private var badgeColor: Color {
        switch notification.type {
        case .vote: return Theme.up
        case .comment: return Theme.accent
        case .cook: return Theme.down
        }
    }

    var body: some View {
        NavigationLink(value: notification.recipe_id.map { Route.recipe(id: $0) }) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    AuthorAvatar(username: notification.actor?.username ?? notification.actor_id ?? "?", size: 44)
                    Circle().fill(badgeColor.opacity(0.15)).frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Theme.raised, lineWidth: 2))
                        .overlay(Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(badgeColor))
                }
                VStack(alignment: .leading, spacing: 2) {
                    (Text(notification.actor?.username ?? "Someone").fontWeight(.bold)
                     + Text(" \(verb) ").foregroundColor(Theme.muted)
                     + Text(notification.recipe.map { "\($0.emoji) \($0.title)" } ?? "your recipe").fontWeight(.semibold))
                        .font(.system(size: 14))
                    Text(Format.timeAgo(notification.created_at)).font(.system(size: 12)).foregroundStyle(Theme.faint)
                }
                Spacer()
                if !notification.read {
                    Circle().fill(Theme.accent).frame(width: 10, height: 10)
                }
            }
            .padding(14)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
        }
        .buttonStyle(.plain)
        .disabled(notification.recipe_id == nil)
    }
}
