import AppIntents
import Foundation

struct WhatsForDinnerIntent: AppIntent {
    static var title: LocalizedStringResource = "What's for dinner"
    static var description = IntentDescription("Open tonight's planned meal in Cook Mode.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        if let tonight = KitchenSnapshot.tonight() {
            await MainActor.run { AppEnvironment.shared.deepLinks.openCook(tonight.recipeId) }
            return .result(dialog: "Tonight it's \(tonight.title).")
        }
        await MainActor.run { AppEnvironment.shared.deepLinks.activeTab = .cookbook }
        return .result(dialog: "Nothing planned yet. I opened your cookbook so you can build a prep bundle.")
    }
}

struct CookNextStepIntent: AppIntent {
    static var title: LocalizedStringResource = "Next cook step"
    static var description = IntentDescription("Advance Cook Mode to the next step.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run { AppEnvironment.shared.deepLinks.issueCookCommand("next") }
        return .result(dialog: "Next step.")
    }
}

struct CookStartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start cook timer"
    static var description = IntentDescription("Start the timer on the current Cook Mode step.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run { AppEnvironment.shared.deepLinks.issueCookCommand("timer") }
        return .result(dialog: "Timer started.")
    }
}

struct AdaptableShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhatsForDinnerIntent(),
            phrases: [
                "What's for dinner in \(.applicationName)",
                "What's for dinner tonight in \(.applicationName)",
            ],
            shortTitle: "Tonight",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: CookNextStepIntent(),
            phrases: ["Next step in \(.applicationName)"],
            shortTitle: "Next step",
            systemImageName: "forward.fill"
        )
        AppShortcut(
            intent: CookStartTimerIntent(),
            phrases: ["Start timer in \(.applicationName)"],
            shortTitle: "Start timer",
            systemImageName: "timer"
        )
    }
}
