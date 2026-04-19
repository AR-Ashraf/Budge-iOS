import SwiftUI
import UIKit

// MARK: - Top bar (logo, currency, menu)

struct ChatChromeTopBar: View {
    let currencyCode: String
    let balanceText: String
    /// True while finance snapshot / FX conversion is in flight (show spinner in pill).
    var isBalanceLoading: Bool = false
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
                    if isBalanceLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                            .tint(palette.currencyPillAccent)
                            // Match ``currencyGlyph`` image frame (18×18).
                            .frame(width: 18, height: 18)
                    } else {
                        Text(balanceText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.currencyPillAccent)
                    }
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
            .accessibilityLabel(isBalanceLoading ? "Loading total balance" : "Total balance \(balanceText) \(currencyCode), open balance sheet")

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

// MARK: - Voice spectrum (real levels, scrolls right → left)

/// Bars reflect sequential RMS samples from the mic (several per buffer). Oldest on the left, newest on the right — new audio enters on the right and pushes older samples left.
/// `revealProgress` 0…1: area unmasks from the **trailing** edge toward the leading edge over the first seconds of recording.
struct VoiceScrollingSpectrumView: View {
    let samples: [CGFloat]
    let palette: BudgeChatPalette
    /// Horizontal reveal 0…1 (right → left); use `transcriber.waveformRevealProgress`.
    var revealProgress: CGFloat = 1

    private let maxBars = 48
    private let minBarHeight: CGFloat = 3
    private let maxBarHeight: CGFloat = 38

    private var displayLevels: [CGFloat] {
        let pad: CGFloat = 0.06
        if samples.count >= maxBars {
            return Array(samples.suffix(maxBars))
        }
        let padCount = maxBars - samples.count
        return Array(repeating: pad, count: padCount) + samples
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(displayLevels.enumerated()), id: \.offset) { _, level in
                let h = minBarHeight + min(1, max(0, level)) * (maxBarHeight - minBarHeight)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.brandGreenPrimary)
                    .frame(width: 3, height: max(minBarHeight, min(maxBarHeight, h)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .mask {
            Rectangle()
                .scaleEffect(x: max(0.04, min(1, revealProgress)), y: 1, anchor: .trailing)
        }
        .accessibilityLabel("Voice level")
    }
}

// MARK: - Composer (multiline + expanded sheet)

private struct ComposerInnerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum ComposerMultilineMetrics {
    static let maxVisibleLines = 6
    static let overflowAtLine = 7
    static var bodyFont: UIFont { UIFont.preferredFont(forTextStyle: .body) }
    static var lineHeight: CGFloat { max(1, bodyFont.lineHeight) }
    static var maxContentHeight: CGFloat { lineHeight * CGFloat(maxVisibleLines) }

    /// Line estimate without touching `UITextView.layoutManager` (avoids TextKit 1 compatibility mode + layout churn).
    static func estimatedLineCount(text: String, font: UIFont, contentWidth: CGFloat) -> Int {
        let w = max(1, contentWidth)
        guard !text.isEmpty else { return 1 }
        let ns = text as NSString
        let h = ns.boundingRect(
            with: CGSize(width: w, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).height
        guard h.isFinite, h >= 0 else { return 1 }
        let lh = max(1, font.lineHeight)
        return max(1, Int(ceil(h / lh)))
    }
}

/// Multiline input with growing height up to `maxVisibleLines`, then internal scroll + overflow callback for expand affordance.
private struct ComposerMultilineTextView: UIViewRepresentable {
    @Binding var text: String
    var isEditable: Bool
    var textColor: UIColor
    var availableWidth: CGFloat

    var onContentHeightChange: (CGFloat) -> Void
    var onNeedsExpandChromeChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = ComposerMultilineMetrics.bodyFont
        tv.textColor = textColor
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.widthTracksTextView = true
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.isScrollEnabled = false
        tv.autocorrectionType = .yes
        tv.autocapitalizationType = .sentences
        tv.keyboardDismissMode = .interactive
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.text = text
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self

        if uiView.font == nil { uiView.font = ComposerMultilineMetrics.bodyFont }
        uiView.textColor = textColor
        uiView.isEditable = isEditable
        uiView.isSelectable = isEditable

        let textSynced: Bool
        if uiView.text != text {
            uiView.text = text
            textSynced = true
        } else {
            textSynced = false
        }

        if !isEditable {
            uiView.resignFirstResponder()
        }

        let widthTick = abs(context.coordinator.lastLayoutWidth - availableWidth) > 0.5
        if widthTick {
            context.coordinator.lastLayoutWidth = availableWidth
        }

        if textSynced || widthTick {
            context.coordinator.layoutAndReport(uiView)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ComposerMultilineTextView
        var lastLayoutWidth: CGFloat = -1
        private var lastEmittedHeight: CGFloat = -1
        private var lastEmittedExpand: Bool?

        init(_ parent: ComposerMultilineTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            let next = textView.text ?? ""
            if parent.text != next {
                parent.text = next
            }
            layoutAndReport(textView)
        }

        func layoutAndReport(_ textView: UITextView) {
            let font = textView.font ?? ComposerMultilineMetrics.bodyFont
            let lineH = ComposerMultilineMetrics.lineHeight
            let insetV = textView.textContainerInset.top + textView.textContainerInset.bottom
            let layoutWidth = max(
                1,
                textView.bounds.width > 10 ? textView.bounds.width : parent.availableWidth
            )
            // Width available to wrapped text (matches typical UITextView layout).
            let textWidth = max(
                1,
                layoutWidth - textView.textContainerInset.left - textView.textContainerInset.right
                    - textView.textContainer.lineFragmentPadding * 2
            )

            // Do not assign a short `textContainer.size.height` (that clips layout and breaks scrolling past ~6 lines).
            // `widthTracksTextView` keeps width in sync with the view bounds; height grows with content for measurement.
            textView.layoutIfNeeded()
            let fitSize = textView.sizeThatFits(CGSize(width: layoutWidth, height: .greatestFiniteMagnitude))
            let rawContentH = max(0, fitSize.height)
            let contentH = rawContentH.isFinite ? rawContentH : lineH

            let lines = ComposerMultilineMetrics.estimatedLineCount(
                text: textView.text ?? "",
                font: font,
                contentWidth: textWidth
            )
            let needsExpandChrome = lines >= ComposerMultilineMetrics.overflowAtLine
            let contentOverflowsViewport = contentH > ComposerMultilineMetrics.maxContentHeight + 0.5
            textView.isScrollEnabled = needsExpandChrome || contentOverflowsViewport

            let cappedForChrome = min(contentH, ComposerMultilineMetrics.maxContentHeight)
            let displayH = max(lineH + insetV, cappedForChrome + insetV)
            let safeDisplayH = displayH.isFinite ? displayH : (lineH + insetV)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let heightChanged = abs(safeDisplayH - self.lastEmittedHeight) >= 0.5
                let expandChanged = self.lastEmittedExpand != needsExpandChrome
                guard heightChanged || expandChanged else { return }
                self.lastEmittedHeight = safeDisplayH
                self.lastEmittedExpand = needsExpandChrome
                self.parent.onContentHeightChange(safeDisplayH)
                self.parent.onNeedsExpandChromeChange(needsExpandChrome)
            }
        }
    }
}

/// Full-height draft editor opened from the inline composer when content reaches 7+ lines.
private struct ChatExpandedComposerSheet: View {
    @Binding var text: String
    let palette: BudgeChatPalette
    let isSending: Bool
    let awaitingAssistantReply: Bool
    let isProcessing: Bool
    let onSend: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var editorFocused: Bool

    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isComposerDisabled: Bool {
        isSending || isProcessing || awaitingAssistantReply
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.body)
                        .foregroundStyle(palette.bodyText)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 64)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(palette.inputInnerBackground)
                        .focused($editorFocused)
                        .disabled(isComposerDisabled)

                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(awaitingAssistantReply ? "Budge is thinking…" : (isProcessing ? "Processing voice…" : "Ask Anything…"))
                            .font(.body)
                            .foregroundStyle(palette.bodyText.opacity(0.45))
                            .padding(.horizontal, 18)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }

                Button {
                    guard hasText else { return }
                    onSend()
                    dismiss()
                } label: {
                    let canSend = hasText && !isComposerDisabled
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.brandGreenDarkText.opacity(canSend ? 1 : 0.45))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(palette.brandGreenPrimary.opacity(canSend ? 1 : 0.38))
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(!hasText || isComposerDisabled)
                .padding(.trailing, 18)
                .padding(.bottom, 18)
                .accessibilityLabel("Send")
            }
            .navigationTitle("Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            editorFocused = true
        }
    }
}

struct ChatComposerChrome: View {
    @Binding var text: String
    let isSending: Bool
    /// After send succeeds, true until the latest Firestore message is from the assistant (covers agentic steps).
    let awaitingAssistantReply: Bool
    let onSend: () -> Void
    @Bindable var transcriber: SpeechTranscriber

    @Environment(\.colorScheme) private var colorScheme

    @State private var multilineContentHeight: CGFloat = 0
    @State private var needsExpandChrome: Bool = false
    @State private var showExpandedSheet: Bool = false
    @State private var innerComposerWidth: CGFloat = 0

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

    private var placeholderPrompt: String {
        awaitingAssistantReply
            ? "Budge is thinking…"
            : (isProcessing ? "Processing voice…" : "Ask Anything…")
    }

    private var effectiveMultilineHeight: CGFloat {
        let minH = ComposerMultilineMetrics.lineHeight + 8
        let defaultH = ComposerMultilineMetrics.lineHeight * 2 + 8
        let rawMeasured = multilineContentHeight > 0 ? multilineContentHeight : defaultH
        let measured = rawMeasured.isFinite ? rawMeasured : defaultH
        let maxH = ComposerMultilineMetrics.maxContentHeight + 8
        return min(max(measured, minH), maxH)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                if isRecording {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(formattedRecordingElapsed(transcriber.recordingElapsed))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(transcriber.isRecordingEndingSoon ? Color.red : palette.bodyText)
                            Text("/ 1:00")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(transcriber.isRecordingEndingSoon ? Color.red.opacity(0.85) : palette.bodyText.opacity(0.5))
                            Spacer(minLength: 0)
                            if transcriber.isRecordingEndingSoon {
                                Text("Wrapping up…")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.red.opacity(0.9))
                            }
                        }
                        VoiceScrollingSpectrumView(
                            samples: transcriber.spectrumHistory,
                            palette: palette,
                            revealProgress: transcriber.waveformRevealProgress
                        )
                    }
                } else {
                    ZStack(alignment: .topLeading) {
                        ComposerMultilineTextView(
                            text: $text,
                            isEditable: !isComposerDisabled,
                            textColor: UIColor(palette.bodyText),
                            availableWidth: max(1, innerComposerWidth),
                            onContentHeightChange: { h in
                                if abs(h - multilineContentHeight) > 0.5 {
                                    multilineContentHeight = h
                                }
                            },
                            onNeedsExpandChromeChange: { flag in
                                if needsExpandChrome != flag {
                                    needsExpandChrome = flag
                                }
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: effectiveMultilineHeight)
                        .accessibilityLabel("Message")

                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(placeholderPrompt)
                                .font(.body)
                                .foregroundStyle(palette.bodyText.opacity(0.45))
                                .padding(.horizontal, 2)
                                .padding(.top, 6)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: ComposerInnerWidthKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(ComposerInnerWidthKey.self) { w in
                guard w > 0.5 else { return }
                if abs(w - innerComposerWidth) > 0.5 {
                    innerComposerWidth = w
                }
            }
            .background(palette.inputInnerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onChange(of: isRecording) { _, recording in
                if !recording {
                    multilineContentHeight = 0
                }
            }

            HStack(alignment: .center, spacing: 10) {
                if needsExpandChrome, !isRecording {
                    Button {
                        showExpandedSheet = true
                    } label: {
                        Image(systemName: "rectangle.expand.vertical")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(palette.bodyText.opacity(0.88))
                            .frame(width: 44, height: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Expand message editor")
                }
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
        .sheet(isPresented: $showExpandedSheet) {
            ChatExpandedComposerSheet(
                text: $text,
                palette: palette,
                isSending: isSending,
                awaitingAssistantReply: awaitingAssistantReply,
                isProcessing: isProcessing,
                onSend: onSend
            )
            .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private var primaryCTA: some View {
        let label: String = {
            if isRecording { return "Stop" }
            if hasText { return "Send" }
            if isProcessing { return "…" }
            return "Voice"
        }()

        Button {
            Task {
                if isRecording {
                    await transcriber.stopRecording(reason: .user)
                } else if hasText {
                    onSend()
                } else if !isProcessing {
                    await transcriber.start()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView()
                        .tint(palette.brandGreenDarkText)
                } else if isRecording {
                    Image(systemName: "stop.fill")
                    Text("Stop")
                } else if hasText {
                    Image(systemName: "paperplane.fill")
                    Text("Send")
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

    /// Only hard-block new sessions when mic/speech permissions are denied. Recoverable recognition errors allow retry (`start()` calls `cancelSession()`).
    private var isProcessingDenied: Bool {
        if case .denied = transcriber.state { return true }
        return false
    }

    private func formattedRecordingElapsed(_ t: TimeInterval) -> String {
        let capped = min(t, SpeechTranscriber.maxRecordingDuration)
        let total = Int(capped.rounded(.down))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
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
            AssistantCopyToolbarButton(
                rawText: rawText,
                secondaryTint: palette.secondaryIcon,
                brandGreen: palette.brandGreenPrimary
            )
            AssistantThumbToolbarButton(kind: .like, secondaryTint: palette.secondaryIcon)
            AssistantThumbToolbarButton(kind: .dislike, secondaryTint: palette.secondaryIcon)
            AssistantSpeakerToolbarButton(
                messageId: messageId,
                rawText: rawText,
                readAloud: readAloud,
                secondaryTint: palette.secondaryIcon
            )
        }
        .padding(.top, 6)
        .padding(.leading, 4)
    }
}

// MARK: - Copy (icon fill + check)

private struct AssistantCopyToolbarButton: View {
    let rawText: String
    let secondaryTint: Color
    let brandGreen: Color

    private enum Phase { case idle, filling, checked }
    @State private var phase: Phase = .idle

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            UIPasteboard.general.string = rawText
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.14)) { phase = .filling }
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.spring(response: 0.28, dampingFraction: 0.74)) { phase = .checked }
                try? await Task.sleep(for: .milliseconds(820))
                withAnimation(.easeOut(duration: 0.26)) { phase = .idle }
            }
        } label: {
            ZStack {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(secondaryTint)
                    .opacity(phase == .idle ? 1 : 0)

                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(brandGreen)
                    .opacity(phase == .filling ? 1 : 0)
                    .scaleEffect(phase == .filling ? 1.05 : 1)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, brandGreen)
                    .opacity(phase == .checked ? 1 : 0)
                    .symbolEffect(.bounce, value: phase == .checked)
            }
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy")
    }
}

// MARK: - Like / Dislike (fill then Facebook)

private struct AssistantThumbToolbarButton: View {
    enum Kind { case like, dislike }

    let kind: Kind
    let secondaryTint: Color

    @State private var filled: Bool = false
    @State private var pressed: Bool = false

    private var fillColor: Color {
        switch kind {
        case .like: return Color(red: 0.09, green: 0.55, blue: 0.95)
        case .dislike: return Color(red: 0.95, green: 0.35, blue: 0.28)
        }
    }

    private var systemImage: String {
        switch kind {
        case .like: return "hand.thumbsup"
        case .dislike: return "hand.thumbsdown"
        }
    }

    private var systemImageFilled: String {
        switch kind {
        case .like: return "hand.thumbsup.fill"
        case .dislike: return "hand.thumbsdown.fill"
        }
    }

    private var accessibilityLabel: String {
        switch kind {
        case .like: return "Like"
        case .dislike: return "Dislike"
        }
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                filled = true
                pressed = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(380))
                openFacebook()
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.easeOut(duration: 0.28)) {
                    filled = false
                    pressed = false
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(fillColor.opacity(0.22 + 0.58 * (filled ? 1 : 0)))
                    .scaleEffect(filled ? 1 : 0.2)
                    .opacity(filled ? 1 : 0)

                Image(systemName: filled ? systemImageFilled : systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(filled ? fillColor : secondaryTint)
                    .scaleEffect(pressed ? 0.92 : 1)
            }
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func openFacebook() {
        guard let url = URL(string: "https://facebook.com/mybudgeai") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Read aloud

private struct AssistantSpeakerToolbarButton: View {
    let messageId: String
    let rawText: String
    @Bindable var readAloud: ReadAloudController
    let secondaryTint: Color

    @State private var pressed: Bool = false

    var body: some View {
        let speaking = readAloud.speakingMessageId == messageId
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            readAloud.toggle(messageId: messageId, plainText: rawText)
            withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) { pressed = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { pressed = false }
            }
        } label: {
            ZStack {
                if speaking {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 32, height: 32)
                }
                Image(systemName: speaking ? "stop.fill" : "speaker.wave.2")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(speaking ? Color.red.opacity(0.92) : secondaryTint)
                    .scaleEffect(pressed ? 0.88 : 1)
            }
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(speaking ? "Stop speaking" : "Read aloud")
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
