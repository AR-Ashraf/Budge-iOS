import SwiftUI

struct TypingMarkdownView: View {
    let fullText: String
    let charactersPerSecond: Double
    let onFinished: () -> Void

    @State private var visibleCount: Int = 0
    @State private var timer: Timer?

    init(fullText: String, charactersPerSecond: Double = 60, onFinished: @escaping () -> Void) {
        self.fullText = fullText
        self.charactersPerSecond = charactersPerSecond
        self.onFinished = onFinished
    }

    var body: some View {
        MarkdownView(text: String(fullText.prefix(visibleCount)))
            .onAppear { start() }
            .onDisappear { stop() }
            .onChange(of: fullText) { _, _ in
                // Restart animation for a new message payload.
                visibleCount = 0
                start()
            }
    }

    private func start() {
        stop()
        guard !fullText.isEmpty else {
            onFinished()
            return
        }

        let interval = max(1.0 / max(1, charactersPerSecond), 0.01)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if visibleCount < fullText.count {
                visibleCount += 1
            } else {
                stop()
                onFinished()
            }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}

