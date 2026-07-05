import Foundation
import AVFoundation
import UIKit
import SwiftUI

/// Manages hardware settings specifically for "Cook Mode" where hands-free voice recognition
/// is needed, while respecting other audio playing (like Spotify) and preventing the screen from sleeping.
@Observable
final class CookModeManager {
    static let shared = CookModeManager()

    var isCookModeActive = false

    private init() {}

    /// Enter Cook Mode: Configure audio session and disable idle timer (wake-lock).
    func startCookMode() {
        guard !isCookModeActive else { return }

        configureAudioSession()
        preventScreenSleep(true)

        isCookModeActive = true
        print("Cook Mode Started: Wake-lock active, Audio Session mixed with others.")
    }

    /// Exit Cook Mode: Revert audio session (optional based on your app's needs) and enable idle timer.
    func stopCookMode() {
        guard isCookModeActive else { return }

        preventScreenSleep(false)

        isCookModeActive = false
        print("Cook Mode Stopped: Wake-lock disabled.")
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playAndRecord allows microphone access for SFSpeechRecognizer.
            // .mixWithOthers ensures background music (Spotify, Apple Music)
            // stays playing at a reduced volume instead of being silenced.
            // .duckOthers gives the mic priority over playback for recognition.
            try session.setCategory(.playAndRecord,
                                    mode: .measurement,
                                    options: [.mixWithOthers, .duckOthers, .allowBluetooth])
            try session.setActive(true)
         } catch {
            print("Failed to configure AVAudioSession for Cook Mode: \(error)")
         }
     }

    private func preventScreenSleep(_ prevent: Bool) {
        // Ensure UI updates happen on the Main Actor
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = prevent
        }
    }
}
