import SwiftUI

/// Parity with web `/budge-setup`: `AvatarAnim` + `StarterLayout` (`primary.light` bg, typewriter, mascot, auto-navigate).
struct BudgeSetupIntroView: View {
    let onContinue: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var displayedText = ""
    @State private var bubbleOpacity: Double = 0
    @State private var bubbleOffsetY: CGFloat = 30
    @State private var contentOffsetY: CGFloat = 400
    @State private var avatarOpacity: Double = 0
    @State private var avatarScale: CGFloat = 0.9
    @State private var imageLoaded = false
    @State private var hasNavigated = false
    @State private var didStartTypewriter = false

    @State private var typewriterTask: Task<Void, Never>?

    private static let phrases = ["Hello, I am Budge", "Your Finance Buddy", "Let's Get Started"]

    private var avatarSize: CGFloat {
        horizontalSizeClass == .regular ? 288 : 192
    }

    private var compactSlide: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.budgeAuthBackground.ignoresSafeArea()

            VStack {
                Spacer(minLength: 0)

                VStack(spacing: 24) {
                    speechBubble

                    ZStack {
                        if !imageLoaded {
                            ProgressView()
                                .tint(AppTheme.Colors.budgeGreenPrimary)
                                .scaleEffect(1.2)
                        }

                        Image("charecterDark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: avatarSize, height: avatarSize)
                            .opacity(imageLoaded ? 1 : 0)
                            .animation(.easeInOut(duration: 0.3), value: imageLoaded)
                            .onAppear {
                                imageLoaded = true
                            }
                    }
                    .opacity(avatarOpacity)
                    .scaleEffect(avatarScale)
                }
                .offset(y: compactSlide ? contentOffsetY : 0)
                .padding(.horizontal, UIConstants.Padding.section)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            if compactSlide {
                // Center the content; only a subtle entrance slide on compact widths
                contentOffsetY = 120
                withAnimation(.easeInOut(duration: 0.5)) {
                    contentOffsetY = 0
                }
            }
            withAnimation(.easeInOut(duration: 0.35).delay(0.2)) {
                bubbleOpacity = 1
                bubbleOffsetY = 0
            }
            withAnimation(.easeInOut(duration: 0.5)) {
                avatarOpacity = 1
                avatarScale = 1
            }
            startTypewriterIfNeeded()
        }
        .onDisappear {
            typewriterTask?.cancel()
            typewriterTask = nil
            if !hasNavigated {
                didStartTypewriter = false
                displayedText = ""
            }
        }
    }

    private var speechBubble: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Text(displayedText)
                    .font(.system(size: horizontalSizeClass == .regular ? 17 : 15, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.budgeAuthTextPrimary)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 24)
                    .accessibilityLabel(displayedText)

                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 40 : 20)
            .padding(.vertical, horizontalSizeClass == .regular ? 32 : 24)
            .frame(minWidth: 200)
            .frame(maxWidth: 512)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.Colors.budgeAuthCard)
                    .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.Colors.budgeAuthBorder, lineWidth: 1)
            )

            // Speech tail (web parity: rotated square + border.card)
            speechBubbleTail
                .offset(y: 8)
        }
        .opacity(bubbleOpacity)
        .offset(y: bubbleOffsetY)
    }

    private var speechBubbleTail: some View {
        ZStack {
            Rectangle()
                .fill(AppTheme.Colors.budgeAuthCard)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(45))
            Rectangle()
                .strokeBorder(AppTheme.Colors.budgeAuthBorder, lineWidth: 1)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(45))
        }
        .frame(width: 22, height: 11)
        .clipped()
    }

    private func startTypewriterIfNeeded() {
        guard !didStartTypewriter else { return }
        didStartTypewriter = true
        typewriterTask?.cancel()
        typewriterTask = Task { @MainActor in
            let charDelayNs: UInt64 = 45_000_000
            let pauseNs: UInt64 = 400_000_000
            let deleteStepNs: UInt64 = 10_000_000

            for (index, phrase) in Self.phrases.enumerated() {
                if Task.isCancelled { return }

                for ch in phrase {
                    if Task.isCancelled { return }
                    displayedText.append(ch)
                    try? await Task.sleep(nanoseconds: charDelayNs)
                }

                if index < Self.phrases.count - 1 {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: pauseNs)
                    while !displayedText.isEmpty {
                        if Task.isCancelled { return }
                        displayedText.removeLast()
                        try? await Task.sleep(nanoseconds: deleteStepNs)
                    }
                } else {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: pauseNs)
                    guard !hasNavigated else { return }
                    hasNavigated = true
                    onContinue()
                }
            }
        }
    }
}
