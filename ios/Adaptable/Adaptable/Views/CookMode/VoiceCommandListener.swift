import Foundation
import Speech
import AVFoundation

/// Hands-free Cook Mode voice commands ("next", "back", "ingredients",
/// "start timer"). Mirrors SpeechRecognition usage on the web Cook Mode page.
@MainActor
final class VoiceCommandListener: ObservableObject {
    @Published private(set) var isListening = false
    /// User-facing status when mic/speech is unavailable or denied.
    @Published private(set) var statusMessage: String?

    var onNext: (() -> Void)?
    var onBack: (() -> Void)?
    var onShowIngredients: (() -> Void)?
    var onHideIngredients: (() -> Void)?
    var onStartTimer: (() -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var lastHandled = ""
    private var lastHandledAt = Date.distantPast

    func start() {
        guard !isListening else { return }
        statusMessage = nil

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.beginSession()
                case .denied, .restricted:
                    self.statusMessage = "Speech recognition is off — enable it in Settings → Adaptable."
                case .notDetermined:
                    self.statusMessage = "Speech permission is required for voice commands."
                @unknown default:
                    self.statusMessage = "Speech recognition isn't available right now."
                }
            }
        }
    }

    private func beginSession() {
        guard let recognizer, recognizer.isAvailable else {
            statusMessage = "Speech recognition isn't available on this device."
            return
        }

        // Ensure playAndRecord is active even if CookModeManager was missed.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetoothHFP, .defaultToSpeaker, .mixWithOthers]
            )
            try session.setActive(true, options: [])
        } catch {
            print("[VoiceCommandListener] Audio session failed: \(error)")
            statusMessage = "Couldn't access the microphone."
            return
        }

        // Mic permission (separate from speech recognition).
        switch AVAudioApplication.shared.recordPermission {
        case .denied:
            statusMessage = "Microphone access is off — enable it in Settings → Adaptable."
            return
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.beginSession()
                    } else {
                        self?.statusMessage = "Microphone access is off — enable it in Settings → Adaptable."
                    }
                }
            }
            return
        case .granted:
            break
        @unknown default:
            break
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = false
        request = req

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            statusMessage = "No microphone input available."
            return
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            statusMessage = "Couldn't start listening."
            return
        }

        isListening = true
        statusMessage = nil
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
        // Debounce: ignore repeats of the same phrase within 1.2s so partial
        // results don't fire "next" three times while the user is speaking.
        let now = Date()
        if heard == lastHandled, now.timeIntervalSince(lastHandledAt) < 1.2 { return }

        let triggered: Bool
        if matches(heard, anyOf: ["next", "continue", "done", "forward"]) {
            onNext?(); triggered = true
        } else if matches(heard, anyOf: ["back", "previous"]) {
            onBack?(); triggered = true
        } else if heard.contains("ingredient") {
            onShowIngredients?(); triggered = true
        } else if matches(heard, anyOf: ["close", "hide"]) {
            onHideIngredients?(); triggered = true
        } else if heard.contains("timer") {
            onStartTimer?(); triggered = true
        } else {
            triggered = false
        }

        if triggered {
            lastHandled = heard
            lastHandledAt = now
        }
    }

    private func matches(_ heard: String, anyOf words: [String]) -> Bool {
        words.contains { heard.contains($0) }
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
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        if deactivateSession {
            // CookModeManager owns full teardown when leaving Cook Mode;
            // only deactivate if voice is toggled off mid-session.
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
