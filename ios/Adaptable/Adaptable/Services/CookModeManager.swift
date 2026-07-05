import Foundation
import AVFoundation
import UIKit

/// Manages hardware-level configurations for Cook Mode, including audio session
/// orchestration and screen sleep prevention.
enum CookModeManager {

    /// Prepares the device for hands-free cooking.
    static func startCookMode() {
        // 1. Audio Session Orchestration
        // Use .playAndRecord so we can use the mic, but add .mixWithOthers
        // so background music (Spotify/Apple Music) continues playing.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
            print("CookModeManager: Audio session configured for mixed play/record")
        } catch {
            print("CookModeManager: Failed to configure audio session: \(error)")
        }

        // 2. Prevent Screen Sleep
        // Disable the idle timer so the screen stays on while following a recipe.
        UIApplication.shared.isIdleTimerDisabled = true
        print("CookModeManager: Idle timer disabled (Screen Awake)")
    }

    /// Restores device hardware to standard settings.
    static func stopCookMode() {
        // 1. Restore Audio Session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default) // Reset to default playback
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            print("CookModeManager: Audio session restored to playback")
        } catch {
            print("CookModeManager: Failed to restore audio session: \(error)")
        }

        // 2. Re-enable Screen Sleep
        UIApplication.shared.isIdleTimerDisabled = false
        print("CookModeManager: Idle timer re-enabled (Screen Sleep active)")
    }
}
