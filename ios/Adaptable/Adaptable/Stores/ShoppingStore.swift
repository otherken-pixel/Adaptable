import Foundation

/// Grocery list state shared across Recipe view, Cookbook planner and the
/// Groceries tab. Mirrors `src/context/ShoppingContext.tsx`.
@MainActor
final class ShoppingStore: ObservableObject {
    @Published private(set) var items: [ShoppingItem] = []

    private var loadedForProfileId: String?

    var uncheckedCount: Int { items.filter { !$0.checked }.count }

    func load(for profile: Profile?) async {
        guard let profile else {
            items = []
            loadedForProfileId = nil
            return
        }
        guard loadedForProfileId != profile.id else { return }
        loadedForProfileId = profile.id
        items = (try? await API.fetchShoppingItems(userId: profile.id)) ?? []
    }

    func addRecipe(_ recipe: Recipe, scaleFactor: Double, userId: String) {
        let rows = (recipe.ingredients ?? []).map { ing in
            (recipeId: Optional(recipe.id), recipeTitle: recipe.title ?? "", item: ing.item, quantity: Quantity.scale(ing.quantity, factor: scaleFactor))
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let temp = rows.enumerated().map { i, r in
            ShoppingItem(id: "tmp-\(Int(Date().timeIntervalSince1970 * 1000))-\(i)", recipe_id: r.recipeId, recipe_title: r.recipeTitle, item: r.item, quantity: r.quantity, checked: false, created_at: now)
        }
        items = temp + items

        Task {
            do {
                let created = try await API.addShoppingItems(userId: userId, rows: rows)
                items = created + items.filter { item in !temp.contains { $0.id == item.id } }
            } catch {
                items = items.filter { item in !temp.contains { $0.id == item.id } }
            }
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
        Task {
            do {
                try await API.removeShoppingItem(userId: userId, id: id)
            } catch {
                if let removed { items.insert(removed, at: 0) }
            }
        }
    }

    func clearChecked(userId: String) {
        let previous = items
        items.removeAll { $0.checked }
        Task {
            do {
                try await API.clearCheckedShoppingItems(userId: userId)
            } catch {
                items = previous
            }
        }
    }
}
