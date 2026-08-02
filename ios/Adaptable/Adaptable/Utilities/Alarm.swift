import AudioToolbox
import UIKit
import UserNotifications

/// Timer-finished alert: triple beep + haptic buzz. Mirrors `src/lib/alarm.ts`
/// (which used Web Audio + the Vibration API); native gets a real haptic
/// engine and system sounds instead.
///
/// Also schedules a local notification so timers fire when the screen is locked
/// (lightweight stand-in for a full Live Activity).
enum Alarm {
    static func ring() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        for (index, delay) in [0.0, 0.35, 0.7].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .deadline(after: delay)) {
                AudioServicesPlaySystemSound(1057) // short "tink" system sound
                if index < 2 {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
            }
        }
    }

    /// Schedule a lock-screen banner when a cook timer ends.
    static func scheduleTimerNotification(seconds: Int, step: Int) {
        guard seconds > 0 else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Timer done"
            content.body = step > 0 ? "Step \(step) timer finished — back to cooking!" : "Your cook timer finished."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
            let id = "cook-timer-\(step)-\(Int(Date().timeIntervalSince1970))"
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(req)
        }
    }
}

private extension DispatchTime {
    static func deadline(after seconds: Double) -> DispatchTime {
        .now() + seconds
    }
}
