import AVFoundation
import Foundation
import Speech

@Observable
final class SpeechTranscriber {
    enum State: Equatable {
        case idle
        case recording
        case denied(String)
        case error(String)
    }

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?

    var state: State = .idle
    var transcript: String = ""

    init(locale: Locale = Locale(identifier: "en_US")) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    func requestPermissions() async -> Bool {
        let speechOK = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { auth in
                continuation.resume(returning: auth == .authorized)
            }
        }
        guard speechOK else {
            state = .denied("Speech recognition permission denied.")
            return false
        }

        let micOK = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { ok in
                continuation.resume(returning: ok)
            }
        }
        guard micOK else {
            state = .denied("Microphone permission denied.")
            return false
        }
        return true
    }

    func start() async {
        guard await requestPermissions() else { return }
        stop()

        transcript = ""
        state = .recording

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .error("Failed to start audio session.")
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        guard let recognizer, recognizer.isAvailable else {
            state = .error("Speech recognizer unavailable.")
            return
        }

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcript = result.bestTranscription.formattedString
            }
            if let error {
                self.state = .error(error.localizedDescription)
                self.stop()
            }
        }

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
            state = .error("Failed to start recording.")
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil

        if case .recording = state {
            state = .idle
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

