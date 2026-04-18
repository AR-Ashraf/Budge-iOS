import SwiftUI
import UIKit

// MARK: - Top bar (logo, currency, menu)

struct ChatChromeTopBar: View {
    let currencyCode: String
    let balanceText: String
    let onLogoTap: () -> Void
    let onCurrencyTap: () -> Void
    let onMenuTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = BudgeChatPalette(colorScheme: colorScheme)
        HStack(spacing: 12) {
            Button(action: onLogoTap) {
                Image("mobileBrand")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .accessibilityLabel("New chat")
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button(action: onCurrencyTap) {
                HStack(spacing: 6) {
                    currencyGlyph(for: currencyCode)
                        .foregroundStyle(palette.currencyPillAccent)
                    Text(balanceText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.currencyPillAccent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(palette.currencyPillBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(palette.currencyPillAccent.opacity(0.55), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Total balance \(balanceText) \(currencyCode)")

            Button(action: onMenuTap) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(palette.bodyText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menu")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(palette.screenBackground)
    }

    @ViewBuilder
    private func currencyGlyph(for code: String) -> some View {
        let c = code.uppercased()
        if c == "BDT" {
            Image("bdt")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        } else if c == "EUR" {
            Text("€").font(.subheadline.weight(.semibold))
        } else if c == "GBP" {
            Text("£").font(.subheadline.weight(.semibold))
        } else {
            Text("$").font(.subheadline.weight(.semibold))
        }
    }
}

// MARK: - Welcome hero

struct ChatWelcomeHero: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = BudgeChatPalette(colorScheme: colorScheme)
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("Welcome to Budge!")
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(palette.bodyText)
                    .multilineTextAlignment(.center)

                Image("charecterDark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)

            Text("I am your finance buddy who learns about your finances and helps you grow in secret.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(palette.bodyText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.top, 24)
        .padding(.bottom, 8)
    }
}

// MARK: - Starter prompts

private enum StarterPromptCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct StarterPromptStrip: View {
    let onPick: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var uniformCardHeight: CGFloat = 0

    var body: some View {
        let palette = BudgeChatPalette(colorScheme: colorScheme)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(ChatSuggestedPrompts.items) { item in
                    Button {
                        onPick(item.message)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.bodyText)
                            Text(item.message)
                                .font(.caption)
                                .foregroundStyle(palette.starterCardSubtitle)
                                .lineLimit(4)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(width: 220, alignment: .topLeading)
                        .frame(minHeight: uniformCardHeight > 0 ? uniformCardHeight : nil, alignment: .top)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: StarterPromptCardHeightKey.self,
                                    value: geo.size.height
                                )
                            }
                        )
                        .background(palette.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(palette.borderPrimary.opacity(0.6), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .onPreferenceChange(StarterPromptCardHeightKey.self) { maxMeasured in
                guard maxMeasured > 0 else { return }
                if abs(maxMeasured - uniformCardHeight) > 0.5 {
                    uniformCardHeight = maxMeasured
                }
            }
        }
    }
}

// MARK: - Voice waveform

struct VoiceWaveformBars: View {
    let level: CGFloat
    let palette: BudgeChatPalette

    private let barCount = 24

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0 ..< barCount, id: \.self) { i in
                let phase = sin(Double(i) * 0.45 + Double(level) * 4)
                let h = 8 + CGFloat(phase * 0.5 + 0.5) * 22 * max(0.15, level)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.brandGreenPrimary)
                    .frame(width: 3, height: h)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Composer

struct ChatComposerChrome: View {
    @Binding var text: String
    let isSending: Bool
    /// After send succeeds, true until the latest Firestore message is from the assistant (covers agentic steps).
    let awaitingAssistantReply: Bool
    let onSend: () -> Void
    @Bindable var transcriber: SpeechTranscriber

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var fieldFocused: Bool

    /// After the composer unlocks (e.g. assistant finished), UIKit/SwiftUI often restores first responder; keep keyboard closed until the user taps the field.
    @State private var allowTextFieldFocus: Bool = true

    private var palette: BudgeChatPalette { BudgeChatPalette(colorScheme: colorScheme) }

    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var isRecording: Bool {
        if case .recording = transcriber.state { return true }
        return false
    }

    private var isProcessing: Bool {
        if case .processing = transcriber.state { return true }
        return false
    }

    private var isComposerDisabled: Bool {
        isSending || isProcessing || awaitingAssistantReply
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                if isRecording {
                    VoiceWaveformBars(level: transcriber.meterLevel, palette: palette)
                        .accessibilityLabel("Recording")
                } else {
                    TextField(
                        awaitingAssistantReply
                            ? "Budge is thinking…"
                            : (isProcessing ? "Processing voice…" : "Ask Anything…"),
                        text: $text,
                        axis: .vertical
                    )
                    .font(.body)
                    .foregroundStyle(palette.bodyText)
                    .lineLimit(1 ... 6)
                    .focused($fieldFocused)
                    .disabled(isComposerDisabled)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            allowTextFieldFocus = true
                        }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(palette.inputInnerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack {
                Spacer(minLength: 0)
                primaryCTA
            }
        }
        .padding(10)
        .background(palette.inputOuterBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(palette.borderPrimary, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.12), radius: 10, x: 0, y: 4)
        .onChange(of: fieldFocused) { _, focused in
            if focused, !allowTextFieldFocus {
                fieldFocused = false
                ChatUIDebugLogger.inputFocusSuppressedBecauseImplicit()
                return
            }
            ChatUIDebugLogger.inputFocusChanged(focused)
        }
        .onChange(of: isSending) { _, sending in
            if sending {
                allowTextFieldFocus = false
                fieldFocused = false
                ChatUIDebugLogger.composerLockChanged(locked: true, reason: "isSending")
            }
        }
        .onChange(of: awaitingAssistantReply) { _, awaiting in
            ChatUIDebugLogger.composerLockChanged(locked: awaiting, reason: "awaitingAssistantReply")
            fieldFocused = false
            allowTextFieldFocus = false
            if !awaiting {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(32))
                    if !allowTextFieldFocus { fieldFocused = false }
                    try? await Task.sleep(for: .milliseconds(120))
                    if !allowTextFieldFocus { fieldFocused = false }
                }
            }
        }
    }

    @ViewBuilder
    private var primaryCTA: some View {
        let label: String = {
            if hasText { return "Send" }
            if isRecording { return "Stop" }
            if isProcessing { return "…" }
            return "Voice"
        }()

        Button {
            Task {
                if hasText {
                    onSend()
                } else if isRecording {
                    await transcriber.stopRecording()
                } else if !isProcessing {
                    await transcriber.start()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView()
                        .tint(palette.brandGreenDarkText)
                } else if hasText {
                    Image(systemName: "paperplane.fill")
                    Text("Send")
                } else if isRecording {
                    Image(systemName: "stop.fill")
                    Text("Stop")
                } else {
                    Image(systemName: "waveform")
                    Text("Voice")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isRecording ? Color.white : palette.brandGreenDarkText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isRecording ? Color.red.opacity(0.92) : palette.brandGreenPrimary)
            .clipShape(Capsule())
        }
        .disabled(isComposerDisabled || isProcessingDenied)
        .accessibilityLabel(label)
    }

    private var isProcessingDenied: Bool {
        if case .denied = transcriber.state { return true }
        if case .error = transcriber.state { return true }
        return false
    }
}

// MARK: - Assistant toolbar

struct AssistantMessageToolbar: View {
    let messageId: String
    let rawText: String
    @Bindable var readAloud: ReadAloudController

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = BudgeChatPalette(colorScheme: colorScheme)
        HStack(spacing: 4) {
            toolbarIcon("doc.on.doc", label: "Copy", tint: palette.secondaryIcon) {
                UIPasteboard.general.string = rawText
            }
            toolbarIcon("hand.thumbsup", label: "Like", tint: palette.secondaryIcon) {
                openReviewURL()
            }
            toolbarIcon("hand.thumbsdown", label: "Dislike", tint: palette.secondaryIcon) {
                openReviewURL()
            }
            let speaking = readAloud.speakingMessageId == messageId
            toolbarIcon(
                speaking ? "stop.fill" : "speaker.wave.2",
                label: speaking ? "Stop speaking" : "Read aloud",
                tint: speaking ? Color.red.opacity(0.9) : palette.secondaryIcon
            ) {
                readAloud.toggle(messageId: messageId, plainText: rawText)
            }
        }
        .padding(.top, 6)
        .padding(.leading, 4)
    }

    private func toolbarIcon(_ system: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func openReviewURL() {
        guard let url = URL(string: "https://apps.apple.com/search?term=MyBudge") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Scroll FAB

struct ChatScrollDownFab: View {
    let visible: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = BudgeChatPalette(colorScheme: colorScheme)
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.brandGreenPrimary)
                .frame(width: 36, height: 36)
                .background(palette.scrollFabBackground)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .accessibilityLabel("Scroll to bottom")
    }
}
