import AudioToolbox
import UIKit

/// Timer-finished alert: triple beep + haptic buzz. Mirrors `src/lib/alarm.ts`
/// (which used Web Audio + the Vibration API); native gets a real haptic
/// engine and system sounds instead.
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
}

private extension DispatchTime {
    static func deadline(after seconds: Double) -> DispatchTime {
        .now() + seconds
    }
}
