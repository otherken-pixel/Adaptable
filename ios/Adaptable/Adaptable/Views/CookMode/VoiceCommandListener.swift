import Foundation
import Speech
import AVFoundation

/// Hands-free Cook Mode voice commands ("next", "back", "ingredients",
/// "start timer"). Mirrors the SpeechRecognition usage in
/// `src/pages/CookModePage.tsx`.
@MainActor
final class VoiceCommandListener: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var lastError = false

    var onNext: (() -> Void)?
    var onBack: (() -> Void)?
    var onShowIngredients: (() -> Void)?
    var onHideIngredients: (() -> Void)?
    var onStartTimer: (() -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() {
        guard !isListening else { return }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                guard status == .authorized else {
                    self.lastError = true
                    return
                }
                self.beginSession()
            }
        }
    }

    private func beginSession() {
        guard let recognizer, recognizer.isAvailable else { lastError = true; return }
        // NOTE: The audio session category must already be configured by
         // CookModeManager.startCookMode() before this method is called.
        // We activate the session (required for mic input) without changing
        // the category — leaving .playAndRecord with .mixWithOthers intact
         // so background music keeps playing at reduced volume.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true, options: .notifyOthersOnDeactivation)
         } catch {
            print("Failed to activate audio session for voice recognition: \(error)")
            lastError = true
            return
          }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = false
        request = req

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            lastError = true
            return
        }

        isListening = true
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let heard = result.bestTranscription.formattedString.lowercased()
                Task { @MainActor in self.handle(heard) }
            }
            if error != nil {
                Task { @MainActor in
                    if self.isListening { self.restart() }
                }
            }
        }
    }

    private func handle(_ heard: String) {
        if heard.contains("next") || heard.contains("continue") || heard.contains("done") || heard.contains("forward") {
            onNext?()
        } else if heard.contains("back") || heard.contains("previous") {
            onBack?()
        } else if heard.contains("ingredient") {
            onShowIngredients?()
        } else if heard.contains("close") || heard.contains("hide") {
            onHideIngredients?()
        } else if heard.contains("timer") {
            onStartTimer?()
        }
    }

    private func restart() {
        stop(deactivateSession: false)
        beginSession()
    }

    func stop() {
        stop(deactivateSession: true)
    }

    private func stop(deactivateSession: Bool) {
        isListening = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
