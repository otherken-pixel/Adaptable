import Foundation

/// Grocery list state shared across Recipe view, Cookbook planner and the
/// Groceries tab. Mirrors `src/context/ShoppingContext.tsx` (merge + offline queue).
@MainActor
final class ShoppingStore: ObservableObject {
    @Published private(set) var items: [ShoppingItem] = []
    @Published private(set) var pendingSync = 0

    private var loadedForProfileId: String?
    private var offlineQueue: [OfflineOp] = []
    /// Legacy unscoped key — removed on load so it cannot be replayed for the wrong user.
    private let legacyQueueKey = "adaptable.shopping.offlineQueue.v1"

    private enum OfflineOp: Codable {
        case toggle(id: String, checked: Bool)
        case remove(id: String)
        case clearChecked
    }

    private func queueKey(for userId: String) -> String {
        "\(legacyQueueKey).\(userId)"
    }

    var uncheckedCount: Int { items.filter { !$0.checked }.count }

    func load(for profile: Profile?) async {
        guard let profile else {
            items = []
            loadedForProfileId = nil
            offlineQueue = []
            pendingSync = 0
            return
        }
        // Drop legacy unscoped queue so a prior account's ops cannot flush for this user.
        UserDefaults.standard.removeObject(forKey: legacyQueueKey)
        loadQueue(for: profile.id)
        if loadedForProfileId == profile.id {
            await flushQueue(userId: profile.id)
            return
        }
        do {
            items = try await API.fetchShoppingItems(userId: profile.id)
            loadedForProfileId = profile.id
        } catch {
            // Don't mark loaded — a failed fetch used to look like an empty
            // list forever because the next load() bailed out.
        }
        await flushQueue(userId: profile.id)
    }

    func addRecipe(
        _ recipe: Recipe,
        scaleFactor: Double,
        userId: String,
        skipKeys: Set<String> = []
    ) async {
        var existing: [String: ShoppingItem] = [:]
        for item in items where !item.checked {
            let key = GroceryMerge.normalizeKey(item.item)
            if existing[key] == nil { existing[key] = item }
        }

        var rows: [(recipeId: String?, recipeTitle: String, item: String, quantity: String)] = []
        var mergedIds: [(id: String, quantity: String)] = []
        for ing in recipe.ingredients ?? [] {
            if skipKeys.contains(GroceryMerge.batchKey(ing.item)) { continue }
            let key = GroceryMerge.normalizeKey(ing.item)
            let qty = Quantity.scale(ing.quantity, factor: scaleFactor)
            if let hit = existing[key] {
                let merged = GroceryMerge.mergeQuantities(existing: hit.quantity, incoming: qty)
                items = items.map {
                    guard $0.id == hit.id else { return $0 }
                    var copy = $0
                    copy.quantity = merged
                    return copy
                }
                if !hit.id.hasPrefix("tmp-") {
                    mergedIds.append((hit.id, merged))
                }
                if let updated = items.first(where: { $0.id == hit.id }) {
                    existing[key] = updated
                }
            } else {
                rows.append((recipe.id, recipe.title ?? "", ing.item, qty))
            }
        }
        for pair in mergedIds {
            try? await API.updateShoppingItemQuantity(userId: userId, id: pair.id, quantity: pair.quantity)
        }
        guard !rows.isEmpty else {
            Haptics.success()
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let temp = rows.enumerated().map { i, r in
            ShoppingItem(
                id: "tmp-\(Int(Date().timeIntervalSince1970 * 1000))-\(i)",
                recipe_id: r.recipeId,
                recipe_title: r.recipeTitle,
                item: r.item,
                quantity: r.quantity,
                checked: false,
                created_at: now
            )
        }
        items = temp + items
        Haptics.success()

        do {
            let created = try await API.addShoppingItems(userId: userId, rows: rows)
            items = created + items.filter { item in !temp.contains { $0.id == item.id } }
        } catch {
            items = items.filter { item in !temp.contains { $0.id == item.id } }
        }
    }

    /// Add a bundle: leftover children skip the shared base (already on the list from the parent).
    func addBundle(_ bundle: MealPrepBundle, userId: String, householdSize: Int?) async {
        let skip = Set(bundle.leftover_focus.map { MealPrepBundles.normalizeIngredient($0) })
        for (index, recipe) in bundle.recipes.enumerated() {
            let scale = Double(householdSize ?? recipe.servings ?? 2) / Double(max(recipe.servings ?? 1, 1))
            // First meal is the batch-cook; later meals reuse that base.
            await addRecipe(recipe, scaleFactor: scale, userId: userId, skipKeys: index == 0 ? [] : skip)
        }
    }

    func toggle(_ id: String, userId: String) {
        guard let target = items.first(where: { $0.id == id }) else { return }
        let next = !target.checked
        items = items.map {
            var i = $0
            if i.id == id { i.checked = next }
            return i
        }
        Haptics.selection()
        if !NetworkMonitor.shared.isOnline {
            enqueue(.toggle(id: id, checked: next), userId: userId)
            return
        }
        Task {
            do {
                try await API.setShoppingItemChecked(userId: userId, id: id, checked: next)
            } catch {
                items = items.map {
                    var i = $0
                    if i.id == id { i.checked = !next }
                    return i
                }
            }
        }
    }

    func remove(_ id: String, userId: String) {
        let removed = items.first { $0.id == id }
        items.removeAll { $0.id == id }
        if !NetworkMonitor.shared.isOnline {
            enqueue(.remove(id: id), userId: userId)
            return
        }
        Task {
            do {
                try await API.removeShoppingItem(userId: userId, id: id)
            } catch {
                if let removed { items.insert(removed, at: 0) }
            }
        }
    }

    func clearChecked(userId: String) {
        let removed = items.filter(\.checked)
        guard !removed.isEmpty else { return }
        items = items.filter { !$0.checked }
        if !NetworkMonitor.shared.isOnline {
            enqueue(.clearChecked, userId: userId)
            return
        }
        Task {
            do {
                try await API.clearCheckedShoppingItems(userId: userId)
            } catch {
                items = removed + items
            }
        }
    }

    // MARK: - Offline queue

    private func enqueue(_ op: OfflineOp, userId: String) {
        // Persist under the caller-provided user. If profile switched before
        // `load` updated `loadedForProfileId`, swap in that user's queue first
        // so we don't write the previous account's in-memory ops to the new key.
        if loadedForProfileId != userId {
            loadQueue(for: userId)
        }
        offlineQueue.append(op)
        pendingSync = offlineQueue.count
        persistQueue(for: userId)
    }

    private func loadQueue(for userId: String) {
        guard let data = UserDefaults.standard.data(forKey: queueKey(for: userId)),
              let ops = try? JSONDecoder().decode([OfflineOp].self, from: data)
        else {
            offlineQueue = []
            pendingSync = 0
            return
        }
        offlineQueue = ops
        pendingSync = ops.count
    }

    private func persistQueue(for userId: String) {
        let key = queueKey(for: userId)
        if offlineQueue.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(offlineQueue) {
            UserDefaults.standard.set(data, forKey: key)
        }
        pendingSync = offlineQueue.count
    }

    private func flushQueue(userId: String) async {
        guard NetworkMonitor.shared.isOnline, !offlineQueue.isEmpty else { return }
        var remaining: [OfflineOp] = []
        for op in offlineQueue {
            do {
                switch op {
                case .toggle(let id, let checked):
                    try await API.setShoppingItemChecked(userId: userId, id: id, checked: checked)
                case .remove(let id):
                    try await API.removeShoppingItem(userId: userId, id: id)
                case .clearChecked:
                    try await API.clearCheckedShoppingItems(userId: userId)
                }
            } catch {
                remaining.append(op)
            }
        }
        offlineQueue = remaining
        persistQueue(for: userId)
        if remaining.count < pendingSync || remaining.isEmpty {
            items = (try? await API.fetchShoppingItems(userId: userId)) ?? items
        }
    }
}
