import SwiftUI

/// Grocery list grouped by source recipe. Mirrors `src/pages/ShoppingListPage.tsx`.
struct ShoppingListView: View {
    @EnvironmentObject private var shoppingStore: ShoppingStore
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var deepLinks: DeepLinkCenter

    private var groups: [(String, [ShoppingItem])] {
        var byRecipe: [String: [ShoppingItem]] = [:]
        var order: [String] = []
        for item in shoppingStore.items {
            let key = item.recipe_title.isEmpty ? "Other items" : item.recipe_title
            if byRecipe[key] == nil { order.append(key) }
            byRecipe[key, default: []].append(item)
        }
        return order.map { ($0, byRecipe[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if shoppingStore.items.isEmpty {
                    EmptyStateView(emoji: "🛒", title: "Nothing on the list", message: "Open any recipe and tap \u{201C}Add to groceries\u{201D} — ingredients land here, scaled to your servings.") {
                        PillButton(title: "Browse recipes") { deepLinks.activeTab = .discover }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(groups, id: \.0) { title, items in
                            let done = items.filter(\.checked).count
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(title).font(.system(size: 15, weight: .heavy))
                                    Spacer()
                                    Text("\(done)/\(items.count)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint)
                                }
                                VStack(spacing: 0) {
                                    ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                                        if i > 0 { Divider().overlay(Theme.line) }
                                        itemRow(item)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.surface)
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(shoppingStore.uncheckedCount > 0 ? "\(shoppingStore.uncheckedCount) TO GRAB" : "ALL SET")
                    .font(.system(size: 12, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.accent)
                Text("Groceries").font(.system(size: 32, weight: .heavy))
            }
            Spacer()
            if shoppingStore.items.count - shoppingStore.uncheckedCount > 0 {
                Button {
                    guard let userId = authStore.profile?.id else { return }
                    shoppingStore.clearChecked(userId: userId)
                } label: {
                    Label("Clear done", systemImage: "trash").font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .foregroundStyle(Theme.muted)
                        .background(Theme.sunken, in: Capsule())
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    private func itemRow(_ item: ShoppingItem) -> some View {
        HStack(spacing: 12) {
            Button {
                guard let userId = authStore.profile?.id else { return }
                shoppingStore.toggle(item.id, userId: userId)
            } label: {
                Circle().strokeBorder(item.checked ? Theme.accent : Theme.line, lineWidth: 2)
                    .background(Circle().fill(item.checked ? Theme.accent : .clear))
                    .frame(width: 22, height: 22)
                    .overlay(item.checked ? Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(.white) : nil)
            }
            Text(item.item).font(.system(size: 15, weight: .semibold)).strikethrough(item.checked)
            Spacer()
            Text(item.quantity).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.muted)
            Button {
                guard let userId = authStore.profile?.id else { return }
                shoppingStore.remove(item.id, userId: userId)
            } label: {
                Image(systemName: "xmark").font(.system(size: 13)).foregroundStyle(Theme.faint).frame(width: 28, height: 28)
            }
        }
        .opacity(item.checked ? 0.45 : 1)
        .padding(.vertical, 10)
    }
}
