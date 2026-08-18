import Foundation
import WidgetKit

/// App Group payload shared with the widget, share extension, and Live Activity.
enum KitchenSnapshot {
    static let suiteName = "group.com.adaptable.app"
    static var defaults: UserDefaults { UserDefaults(suiteName: suiteName) ?? .standard }

    private enum Key {
        static let recipeId = "tonight.recipeId"
        static let title = "tonight.title"
        static let emoji = "tonight.emoji"
        static let date = "tonight.date"
        static let importURL = "pending.importURL"
        static let importText = "pending.importText"
    }

    static func saveTonight(recipeId: String?, title: String?, emoji: String?, date: String?) {
        defaults.set(recipeId, forKey: Key.recipeId)
        defaults.set(title, forKey: Key.title)
        defaults.set(emoji, forKey: Key.emoji)
        defaults.set(date, forKey: Key.date)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func tonight() -> (recipeId: String, title: String, emoji: String, date: String)? {
        guard let id = defaults.string(forKey: Key.recipeId), !id.isEmpty else { return nil }
        return (
            id,
            defaults.string(forKey: Key.title) ?? "Tonight's meal",
            defaults.string(forKey: Key.emoji) ?? "🍽️",
            defaults.string(forKey: Key.date) ?? ""
        )
    }

    static func setPendingImport(url: String?, text: String?) {
        defaults.set(url, forKey: Key.importURL)
        defaults.set(text, forKey: Key.importText)
    }

    static func consumePendingImport() -> (url: String?, text: String?)? {
        let url = defaults.string(forKey: Key.importURL)
        let text = defaults.string(forKey: Key.importText)
        guard url != nil || text != nil else { return nil }
        defaults.removeObject(forKey: Key.importURL)
        defaults.removeObject(forKey: Key.importText)
        return (url, text)
    }

    static func refresh(from plans: [MealPlanEntry]) {
        let today = Format.localISODate()
        let tonight = plans
            .filter { $0.plan_date >= today && $0.recipe != nil }
            .sorted { $0.plan_date < $1.plan_date }
            .first
        saveTonight(
            recipeId: tonight?.recipe_id,
            title: tonight?.recipe?.title,
            emoji: tonight?.recipe?.emoji,
            date: tonight?.plan_date
        )
    }
}
