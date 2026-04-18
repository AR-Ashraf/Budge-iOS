import AVFoundation
import Foundation

@MainActor
@Observable
final class ReadAloudController: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var speakingMessageId: String?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(messageId: String, plainText: String) {
        if speakingMessageId == messageId {
            synthesizer.stopSpeaking(at: .immediate)
            speakingMessageId = nil
            Self.deactivateSpokenAudioSessionIfIdle()
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        let spoken = Self.simplifyForSpeech(plainText)
        guard !spoken.isEmpty else { return }

        do {
            try Self.activateSpokenAudioSession()
        } catch {
            // Still attempt speech; session activation fixes most device/silent-mode issues.
        }

        let utterance = AVSpeechUtterance(string: spoken)
        utterance.voice = Self.preferredEnglishVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        speakingMessageId = messageId
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speakingMessageId = nil
        Self.deactivateSpokenAudioSessionIfIdle()
    }

    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        Task { @MainActor in
            self.speakingMessageId = nil
            Self.deactivateSpokenAudioSessionIfIdle()
        }
    }

    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
        Task { @MainActor in
            self.speakingMessageId = nil
            Self.deactivateSpokenAudioSessionIfIdle()
        }
    }

    /// TTS is inaudible in many setups until the session is configured for spoken output.
    private static func activateSpokenAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: [])
    }

    private static func deactivateSpokenAudioSessionIfIdle() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {}
    }

    private static func preferredEnglishVoice() -> AVSpeechSynthesisVoice? {
        if let v = AVSpeechSynthesisVoice(language: "en-US") { return v }
        return AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix("en") }
    }

    /// Strip code fences / JSON blocks so TTS does not read raw specs.
    private static func simplifyForSpeech(_ raw: String) -> String {
        var s = raw
        if let regex = try? NSRegularExpression(pattern: "```[\\s\\S]*?```", options: []) {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
        }
        return s.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
