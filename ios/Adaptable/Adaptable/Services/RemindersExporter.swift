import EventKit
import Foundation

/// One-way export of the in-app grocery list into Apple Reminders.
/// Finds an existing "Groceries" list when possible, otherwise creates
/// "Adaptable Groceries". Does not sync completion state back.
@MainActor
enum RemindersExporter {
    enum ExportResult: Equatable {
        case success(count: Int, listName: String)
        case empty
        case denied
        case failed(String)
    }

    private static let preferredListNames = ["Groceries", "Grocery", "Grocery List"]
    private static let createdListName = "Adaptable Groceries"
    private static let store = EKEventStore()

    static func export(items: [ShoppingItem]) async -> ExportResult {
        let unchecked = items.filter { !$0.checked }
        guard !unchecked.isEmpty else { return .empty }

        let granted = await requestAccess()
        guard granted else { return .denied }

        do {
            let list = try findOrCreateList()
            for item in unchecked {
                let reminder = EKReminder(eventStore: store)
                let qty = item.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
                if qty.isEmpty {
                    reminder.title = item.item
                } else {
                    reminder.title = "\(item.item) — \(qty)"
                }
                if !item.recipe_title.isEmpty {
                    reminder.notes = "From: \(item.recipe_title)\nAdded via Adaptable"
                } else {
                    reminder.notes = "Added via Adaptable"
                }
                reminder.calendar = list
                try store.save(reminder, commit: false)
            }
            try store.commit()
            return .success(count: unchecked.count, listName: list.title)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Access

    private static func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await store.requestFullAccessToReminders()
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                store.requestAccess(to: .reminder) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Lists

    private static func findOrCreateList() throws -> EKCalendar {
        let existing = store.calendars(for: .reminder)

        for name in preferredListNames {
            if let match = existing.first(where: { $0.title.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
                return match
            }
        }

        if let adaptable = existing.first(where: {
            $0.title.compare(createdListName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            return adaptable
        }

        guard let source = preferredSource(from: store) else {
            throw RemindersError.noSource
        }

        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = createdListName
        list.source = source
        try store.saveCalendar(list, commit: true)
        return list
    }

    private static func preferredSource(from store: EKEventStore) -> EKSource? {
        if let local = store.sources.first(where: { $0.sourceType == .local }) {
            return local
        }
        if let calDAV = store.sources.first(where: { $0.sourceType == .calDAV }) {
            return calDAV
        }
        return store.defaultCalendarForNewReminders()?.source ?? store.sources.first
    }

    private enum RemindersError: LocalizedError {
        case noSource
        var errorDescription: String? {
            "No Reminders account is available on this device."
        }
    }
}
