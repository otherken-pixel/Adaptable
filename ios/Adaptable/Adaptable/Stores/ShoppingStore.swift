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

    private struct QueuedInsert: Equatable, Codable {
        var tempId: String
        var recipeId: String?
        var recipeTitle: String
        var item: String
        var quantity: String
        var checked: Bool

        init(
            tempId: String,
            recipeId: String?,
            recipeTitle: String,
            item: String,
            quantity: String,
            checked: Bool = false
        ) {
            self.tempId = tempId
            self.recipeId = recipeId
            self.recipeTitle = recipeTitle
            self.item = item
            self.quantity = quantity
            self.checked = checked
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            tempId = try c.decode(String.self, forKey: .tempId)
            recipeId = try c.decodeIfPresent(String.self, forKey: .recipeId)
            recipeTitle = try c.decode(String.self, forKey: .recipeTitle)
            item = try c.decode(String.self, forKey: .item)
            quantity = try c.decode(String.self, forKey: .quantity)
            // Pre-checked-field queues must still load.
            checked = try c.decodeIfPresent(Bool.self, forKey: .checked) ?? false
        }
    }

    private enum OfflineOp: Codable {
        case toggle(id: String, checked: Bool)
        case remove(id: String)
        case clearChecked
        case updateQuantity(id: String, quantity: String)
        case insert(rows: [QueuedInsert])
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
            rehydratePendingInserts()
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
        rehydratePendingInserts()
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
                if hit.id.hasPrefix("tmp-") {
                    updateQueuedInsert(tempId: hit.id, quantity: merged, userId: userId)
                } else {
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
            if !NetworkMonitor.shared.isOnline {
                enqueue(.updateQuantity(id: pair.id, quantity: pair.quantity), userId: userId)
                continue
            }
            do {
                try await API.updateShoppingItemQuantity(userId: userId, id: pair.id, quantity: pair.quantity)
            } catch {
                enqueue(.updateQuantity(id: pair.id, quantity: pair.quantity), userId: userId)
            }
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

        let queued = zip(temp, rows).map { item, row in
            QueuedInsert(
                tempId: item.id,
                recipeId: row.recipeId,
                recipeTitle: row.recipeTitle,
                item: row.item,
                quantity: row.quantity
            )
        }
        // Enqueue before the network call so toggle/remove during an in-flight
        // add still find the temp rows.
        enqueue(.insert(rows: queued), userId: userId)
        if NetworkMonitor.shared.isOnline {
            await flushQueue(userId: userId)
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
        // Temp rows only exist in the insert queue — never call the API with tmp- ids.
        if id.hasPrefix("tmp-") {
            updateQueuedInsert(tempId: id, checked: next, userId: userId)
            return
        }
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
        if id.hasPrefix("tmp-") {
            dropQueuedInsert(tempId: id, userId: userId)
            return
        }
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
        let droppedTemps = removed.filter { $0.id.hasPrefix("tmp-") }
        for row in droppedTemps {
            dropQueuedInsert(tempId: row.id, userId: userId)
        }
        let serverRemoved = removed.filter { !$0.id.hasPrefix("tmp-") }
        guard !serverRemoved.isEmpty else { return }
        if !NetworkMonitor.shared.isOnline {
            enqueue(.clearChecked, userId: userId)
            return
        }
        Task {
            do {
                try await API.clearCheckedShoppingItems(userId: userId)
            } catch {
                items = serverRemoved + items
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

    /// Rebuild optimistic temp rows from queued inserts so they survive relaunch.
    private func rehydratePendingInserts() {
        let now = ISO8601DateFormatter().string(from: Date())
        var extras: [ShoppingItem] = []
        for op in offlineQueue {
            guard case .insert(let rows) = op else { continue }
            for row in rows {
                if items.contains(where: { $0.id == row.tempId }) { continue }
                extras.append(
                    ShoppingItem(
                        id: row.tempId,
                        recipe_id: row.recipeId,
                        recipe_title: row.recipeTitle,
                        item: row.item,
                        quantity: row.quantity,
                        checked: row.checked,
                        created_at: now
                    )
                )
            }
        }
        if !extras.isEmpty { items = extras + items }
    }

    private func updateQueuedInsert(tempId: String, quantity: String? = nil, checked: Bool? = nil, userId: String) {
        var changed = false
        offlineQueue = offlineQueue.map { op in
            guard case .insert(var rows) = op else { return op }
            guard let idx = rows.firstIndex(where: { $0.tempId == tempId }) else { return op }
            if let quantity { rows[idx].quantity = quantity }
            if let checked { rows[idx].checked = checked }
            changed = true
            return .insert(rows: rows)
        }
        if changed { persistQueue(for: userId) }
    }

    private func dropQueuedInsert(tempId: String, userId: String) {
        var changed = false
        offlineQueue = offlineQueue.compactMap { op -> OfflineOp? in
            guard case .insert(let rows) = op else { return op }
            let next = rows.filter { $0.tempId != tempId }
            if next.count == rows.count { return op }
            changed = true
            return next.isEmpty ? nil : .insert(rows: next)
        }
        if changed { persistQueue(for: userId) }
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
                case .updateQuantity(let id, let quantity):
                    try await API.updateShoppingItemQuantity(userId: userId, id: id, quantity: quantity)
                case .insert(let rows):
                    let created = try await API.addShoppingItems(
                        userId: userId,
                        rows: rows.map { ($0.recipeId, $0.recipeTitle, $0.item, $0.quantity) }
                    )
                    // Insert succeeded — never re-queue it. Apply later edits from
                    // the live list; a failed check becomes a toggle on the real id.
                    remaining.append(contentsOf: await reconcileCreatedInserts(
                        rows: rows,
                        created: created,
                        userId: userId
                    ))
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

    /// Insert already landed. Never re-queue it. Honor in-flight temp edits
    /// from the live list; a failed check becomes a toggle on the real id.
    private func reconcileCreatedInserts(
        rows: [QueuedInsert],
        created: [ShoppingItem],
        userId: String
    ) async -> [OfflineOp] {
        var followUp: [OfflineOp] = []
        var kept: [ShoppingItem] = []
        let tempIds = Set(rows.map(\.tempId))
        for (index, row) in rows.enumerated() {
            guard index < created.count else { break }
            var server = created[index]
            let live = items.first(where: { $0.id == row.tempId })
            if live == nil {
                followUp.append(.remove(id: server.id))
                continue
            }
            let wantChecked = live?.checked == true || row.checked
            if wantChecked {
                do {
                    try await API.setShoppingItemChecked(userId: userId, id: server.id, checked: true)
                    server.checked = true
                } catch {
                    followUp.append(.toggle(id: server.id, checked: true))
                    server.checked = true
                }
            }
            kept.append(server)
        }
        items = kept + items.filter { !tempIds.contains($0.id) }
        return followUp
    }
}
