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

    enum StopReason: String {
        case user
        case timeout
    }

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?

    var state: State = .idle
    var transcript: String = ""
    /// Normalized 0...1 RMS (latest frame), for any simple level UI.
    var meterLevel: CGFloat = 0
    /// Amplitude history, oldest at index 0, newest at the end — draws as a bar chart that scrolls right → left as new samples arrive.
    private(set) var spectrumHistory: [CGFloat] = []

    /// Monotonic clock for recording UI (updates ~10×/s while recording).
    var recordingElapsed: TimeInterval = 0
    /// `min(1, elapsed / revealDuration)` — mask grows from trailing edge over `waveformRevealDuration` seconds.
    var waveformRevealProgress: CGFloat {
        guard case .recording = state else { return 1 }
        return min(1, CGFloat(recordingElapsed / Self.waveformRevealDuration))
    }

    var isRecordingEndingSoon: Bool {
        guard case .recording = state else { return false }
        return recordingElapsed >= Self.endingSoonThreshold
    }

    /// Visible bars in the composer; history is trimmed to this length.
    private let spectrumBarCount = 48

    private var recordingMonitorTask: Task<Void, Never>?

    /// Max session length (auto-stop).
    static let maxRecordingDuration: TimeInterval = 60
    /// First N seconds: waveform area reveals from the right.
    static let waveformRevealDuration: TimeInterval = 5
    /// After this many seconds, timer styling switches to “ending soon” (red).
    static let endingSoonThreshold: TimeInterval = 50

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
        spectrumHistory = []
        recordingElapsed = 0
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
                    self.handleRecognitionError(error, result: result)
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
            tearDownAudio()
            return
        }

        await startRecordingMonitor()
    }

    @MainActor
    private func startRecordingMonitor() {
        recordingMonitorTask?.cancel()
        let start = Date()
        recordingMonitorTask = Task { @MainActor in
            self.recordingElapsed = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard case .recording = self.state else { break }
                self.recordingElapsed = Date().timeIntervalSince(start)
                if self.recordingElapsed >= Self.maxRecordingDuration {
                    await self.stopRecording(reason: .timeout)
                    break
                }
            }
        }
    }

    @MainActor
    private func handleRecognitionError(_ error: Error, result _: SFSpeechRecognitionResult?) {
        let ns = error as NSError

        // After user stops, state is no longer .recording — ignore late callbacks (common).
        guard case .recording = state else {
            return
        }

        if shouldIgnoreSpeechRecognitionError(ns) {
            return
        }

        state = .error(error.localizedDescription)
        tearDownAudio()
    }

    /// End-of-stream, cancel, and “no speech” are normal; don’t brick the Voice button.
    private func shouldIgnoreSpeechRecognitionError(_ ns: NSError) -> Bool {
        if ns.domain == "kAFAssistantErrorDomain" {
            // 203 = no speech, 216 = cancelled, 301 = often seen on teardown
            return [203, 216, 301].contains(ns.code)
        }
        if ns.domain == "com.apple.Speech" {
            return true
        }
        // kAFAssistantErrorDomain string bridging
        if ns.domain.contains("Assistant") && [203, 216, 301].contains(ns.code) {
            return true
        }
        return false
    }

    private func updateMeter(from buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        let samples = data[0]

        let chunks = 8
        let chunkLen = max(1, n / chunks)
        var chunkLevels: [CGFloat] = []
        chunkLevels.reserveCapacity(chunks)

        for c in 0 ..< chunks {
            let start = c * chunkLen
            let end = min(n, start + chunkLen)
            guard start < end else { break }
            var sum: Float = 0
            let count = end - start
            for i in start ..< end {
                let s = samples[i]
                sum += s * s
            }
            let rms = sqrt(sum / Float(count))
            let normalized = min(1, max(0, CGFloat(rms * 8)))
            chunkLevels.append(normalized)
        }

        Task { @MainActor in
            guard case .recording = self.state else { return }
            for g in chunkLevels {
                let v = min(1, max(0.06, g))
                self.spectrumHistory.append(v)
                if self.spectrumHistory.count > self.spectrumBarCount {
                    self.spectrumHistory.removeFirst(self.spectrumHistory.count - self.spectrumBarCount)
                }
            }
            self.meterLevel = self.spectrumHistory.last ?? 0
        }
    }

    private func tearDownAudio() {
        recordingMonitorTask?.cancel()
        recordingMonitorTask = nil

        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        meterLevel = 0
        spectrumHistory = []
        recordingElapsed = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// User tapped Stop or max duration reached.
    @MainActor
    func stopRecording(reason _: StopReason = .user) async {
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
