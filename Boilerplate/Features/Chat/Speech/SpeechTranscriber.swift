import AVFoundation
import Foundation
import Speech

@Observable
final class SpeechTranscriber {
    enum State: Equatable {
        case idle
        case recording
        case processing
        case denied(String)
        case error(String)
    }

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?

    var state: State = .idle
    var transcript: String = ""
    /// Normalized 0...1 RMS for simple waveform UI.
    var meterLevel: CGFloat = 0

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
        cancelSession()

        transcript = ""
        meterLevel = 0
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
                Task { @MainActor in
                    self.state = .error(error.localizedDescription)
                    self.tearDownAudio()
                }
            }
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.request?.append(buffer)
            self.updateMeter(from: buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            state = .error("Failed to start recording.")
        }
    }

    private func updateMeter(from buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        let samples = data[0]
        var sum: Float = 0
        for i in 0 ..< n {
            let s = samples[i]
            sum += s * s
        }
        let rms = sqrt(sum / Float(n))
        let normalized = min(1, max(0, CGFloat(rms * 6)))
        Task { @MainActor in
            self.meterLevel = normalized
        }
    }

    private func tearDownAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        meterLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// User tapped Stop: end capture, show brief processing, return to idle (web parity).
    @MainActor
    func stopRecording() async {
        guard case .recording = state else { return }
        tearDownAudio()
        state = .processing
        try? await Task.sleep(nanoseconds: 280_000_000)
        if case .processing = state {
            state = .idle
        }
    }

    /// Cancel without processing state (used before a new `start`).
    func cancelSession() {
        tearDownAudio()
        switch state {
        case .recording, .processing, .error, .denied:
            state = .idle
        case .idle:
            break
        }
    }
}
