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
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: Self.simplifyForSpeech(plainText))
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speakingMessageId = messageId
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speakingMessageId = nil
    }

    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        Task { @MainActor in
            self.speakingMessageId = nil
        }
    }

    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
        Task { @MainActor in
            self.speakingMessageId = nil
        }
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
