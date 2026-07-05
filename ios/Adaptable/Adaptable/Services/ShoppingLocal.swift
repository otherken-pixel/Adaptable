import Foundation

/// UserDefaults-backed shopping list used in Demo Mode. Mirrors
/// `src/lib/shoppingLocal.ts`.
@MainActor
final class ShoppingLocal {
    static let shared = ShoppingLocal()

    private let key = "adaptable.shopping.v1"
    private var items: [ShoppingItem]

    private init() {
        if let raw = UserDefaults.standard.data(forKey: "adaptable.shopping.v1"),
           let decoded = try? JSONDecoder().decode([ShoppingItem].self, from: raw) {
            items = decoded
        } else {
            items = []
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func list() -> [ShoppingItem] { items }

    func add(_ rows: [(recipeId: String?, recipeTitle: String, item: String, quantity: String)]) -> [ShoppingItem] {
        let now = ISO8601DateFormatter().string(from: Date())
        let created = rows.map { row in
            ShoppingItem(
                id: "it-\(Int(Date().timeIntervalSince1970 * 1000))-\(Int.random(in: 1000...9999))",
                recipe_id: row.recipeId,
                recipe_title: row.recipeTitle,
                item: row.item,
                quantity: row.quantity,
                checked: false,
                created_at: now
            )
        }
        items = created + items
        persist()
        return created
    }

    func setChecked(_ id: String, checked: Bool) {
        items = items.map {
            var i = $0
            if i.id == id { i.checked = checked }
            return i
        }
        persist()
    }

    func remove(_ id: String) {
        items.removeAll { $0.id == id }
        persist()
    }

    func clearChecked() {
        items.removeAll { $0.checked }
        persist()
    }
}
