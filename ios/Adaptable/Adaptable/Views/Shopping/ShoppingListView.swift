import SwiftUI

/// Grocery list grouped by source recipe. Mirrors `src/pages/ShoppingListPage.tsx`.
struct ShoppingListView: View {
    @EnvironmentObject private var shoppingStore: ShoppingStore
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var deepLinks: DeepLinkCenter

    @State private var remindersBusy = false
    @State private var remindersMessage: String?
    @State private var showRemindersDenied = false

    private var groups: [(String, [ShoppingItem])] {
        var byAisle: [String: [ShoppingItem]] = [:]
        for item in shoppingStore.items {
            let key = GroceryAisle.aisle(for: item.item)
            byAisle[key, default: []].append(item)
        }
        return GroceryAisle.sortAisles(Array(byAisle.keys)).map { ($0, byAisle[$0] ?? []) }
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
                        remindersButton
                        if shoppingStore.pendingSync > 0 || !NetworkMonitor.shared.isOnline {
                            Text(
                                NetworkMonitor.shared.isOnline
                                    ? "\(shoppingStore.pendingSync) change\(shoppingStore.pendingSync == 1 ? "" : "s") syncing…"
                                    : "Offline — checks will sync when you’re back online."
                            )
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.muted)
                        }
                        if let remindersMessage {
                            Text(remindersMessage)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
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
        .alert("Reminders access needed", isPresented: $showRemindersDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Allow Adaptable to add grocery items to Apple Reminders in Settings → Adaptable → Reminders.")
        }
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

    private var remindersButton: some View {
        Button {
            Task { await sendToReminders() }
        } label: {
            HStack(spacing: 8) {
                if remindersBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "checklist")
                }
                Text(shoppingStore.uncheckedCount == 0
                     ? "All items checked — nothing to send"
                     : "Add \(shoppingStore.uncheckedCount) to Apple Reminders")
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .foregroundStyle(Theme.content)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
        }
        .buttonStyle(.pressable)
        .disabled(remindersBusy || shoppingStore.uncheckedCount == 0)
        .opacity(shoppingStore.uncheckedCount == 0 ? 0.55 : 1)
        .accessibilityLabel("Add grocery items to Apple Reminders")
    }

    private func sendToReminders() async {
        remindersBusy = true
        remindersMessage = nil
        let result = await RemindersExporter.export(items: shoppingStore.items)
        remindersBusy = false
        switch result {
        case .success(let count, let listName):
            remindersMessage = "\(count) item\(count == 1 ? "" : "s") added to “\(listName)”"
            Task {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                if remindersMessage?.hasPrefix("\(count)") == true {
                    remindersMessage = nil
                }
            }
        case .empty:
            remindersMessage = "Nothing left to send"
        case .denied:
            showRemindersDenied = true
        case .failed(let message):
            remindersMessage = "Couldn’t add to Reminders: \(message)"
        }
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
