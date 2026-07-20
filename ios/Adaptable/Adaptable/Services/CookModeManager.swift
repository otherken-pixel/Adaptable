import Foundation
import AVFoundation
import UIKit

/// Hardware-level Cook Mode setup: audio session for voice + timers, and
/// screen wake-lock so the phone stays on mid-sauté.
enum CookModeManager {

    /// Prepares the device for hands-free cooking. Safe to call multiple times.
    static func startCookMode() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playAndRecord so the mic works; mixWithOthers keeps Spotify/
            // Apple Music ducking rather than stopping.
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetoothHFP, .defaultToSpeaker, .mixWithOthers]
            )
            try session.setActive(true, options: [])
        } catch {
            print("[CookModeManager] Audio session configure failed: \(error)")
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// Restores normal audio + allows the screen to sleep again.
    static func stopCookMode() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[CookModeManager] Audio session restore failed: \(error)")
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
