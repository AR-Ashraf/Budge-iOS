import SwiftUI
import UIKit

struct ChatView: View {
    @Environment(AuthService.self) private var authService
    @Environment(ChatService.self) private var chatService
    @Environment(OnboardingService.self) private var onboarding

    @State private var model: ChatViewModel?

    var body: some View {
        Group {
            if let model {
                ChatScreen(model: model)
            } else {
                ProgressView()
                    .task { await bootstrapIfPossible() }
            }
        }
    }

    @MainActor
    private func bootstrapIfPossible() async {
        guard let uid = authService.currentUser?.id else { return }
        let chatId = "default"
        let vm = ChatViewModel(chatService: chatService, onboarding: onboarding, uid: uid, chatId: chatId)
        vm.start()
        self.model = vm
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}

private struct ChatScreen: View {
    @Bindable var model: ChatViewModel
    @Environment(Router.self) private var router
    @Environment(\.colorScheme) private var colorScheme

    @State private var transcriber = SpeechTranscriber()
    @State private var readAloud = ReadAloudController()
    /// From `UIScrollView`: `maxContentOffsetY - contentOffset.y`; near 0 at bottom, larger when scrolled up.
    @State private var scrollDistanceFromBottom: CGFloat = 0
    /// Coalesces rapid `scrollTo` requests (send + Firestore updates) so the list does not animate up/down repeatedly.
    @State private var scrollCoalesceToken: UInt64 = 0
    /// Message count when this screen first appeared; used so we only run insertion motion for new assistant turns, not when opening long history.
    @State private var assistantAnimationBaselineCount: Int?

    private var palette: BudgeChatPalette { BudgeChatPalette(colorScheme: colorScheme) }

    private var isEmpty: Bool { model.messages.isEmpty }

    /// Web parity: show chevron when the user has scrolled away from the latest messages (not pinned to bottom).
    private var showScrollFab: Bool {
        !isEmpty && scrollDistanceFromBottom > 80
    }

    /// Resign first responder so the chat field keyboard dismisses when tapping outside the composer.
    private func dismissChatKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Debounced scroll: only the latest request within ~140ms runs (avoids stacked `withAnimation` jank).
    private func scheduleScrollToBottom(_ proxy: ScrollViewProxy, animated: Bool, reason: String) {
        scrollCoalesceToken += 1
        let token = scrollCoalesceToken
        ChatUIDebugLogger.scrollScheduled(reason: reason, animated: animated, token: token)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard token == scrollCoalesceToken else {
                ChatUIDebugLogger.scrollCancelled(staleToken: token, currentToken: scrollCoalesceToken)
                return
            }
            ChatUIDebugLogger.scrollApplied(reason: reason, animated: animated, token: token)
            if animated {
                withAnimation(.easeOut(duration: 0.28)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ChatChromeTopBar(
                    currencyCode: model.headerCurrencyCode,
                    balanceText: model.headerBalanceDisplay,
                    onLogoTap: { model.beginNewChat() },
                    onCurrencyTap: {
                        Task { await model.refreshFinanceHeader() }
                    },
                    onMenuTap: { router.navigate(to: .settings) }
                )
                .simultaneousGesture(TapGesture().onEnded { dismissChatKeyboard() })

                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            // Always laid out (unlike tail cells in LazyVStack) so UIScrollView KVO stays attached.
                            Color.clear
                                .frame(width: 1, height: 1)
                                .background(
                                    ChatScrollOffsetReader { distance in
                                        scrollDistanceFromBottom = distance
                                    }
                                )

                            LazyVStack(alignment: .leading, spacing: 12) {
                                if isEmpty {
                                    ChatWelcomeHero()
                                        .frame(maxWidth: .infinity)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }

                                if let steps = model.approvalState?.agenticSteps, !steps.isEmpty {
                                    AgenticProgressView(steps: steps)
                                        .padding(.top, 4)
                                }

                                ForEach(model.messages) { m in
                                    let animateAssistantInsertion =
                                        m.role == "assistant"
                                        && m.id == model.messages.last?.id
                                        && model.messages.count > (assistantAnimationBaselineCount ?? 0)
                                    MessageRow(
                                        message: m,
                                        readAloud: readAloud,
                                        animateAssistantInsertion: animateAssistantInsertion
                                    )
                                    .id(m.id)
                                }

                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .simultaneousGesture(TapGesture().onEnded { dismissChatKeyboard() })

                    ChatScrollDownFab(visible: showScrollFab) {
                        ChatUIDebugLogger.fabScrollTapped()
                        withAnimation(.easeOut(duration: 0.28)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
                }

                if isEmpty {
                    StarterPromptStrip { picked in
                        model.messageDraft = picked
                    }
                    .padding(.horizontal, 12)
                    .transition(.opacity)
                    .simultaneousGesture(TapGesture().onEnded { dismissChatKeyboard() })
                }

                if let approval = model.approvalState, approval.awaitingApproval {
                    ApprovalCard(
                        approval: approval.pendingApprovals.indices.contains(approval.currentApprovalIndex)
                            ? approval.pendingApprovals[approval.currentApprovalIndex]
                            : nil,
                        onAllow: { choice in Task { await model.approve(choice: choice) } },
                        onDeny: { Task { await model.deny() } }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .simultaneousGesture(TapGesture().onEnded { dismissChatKeyboard() })
                }

                ChatComposerChrome(
                    text: $model.messageDraft,
                    isSending: model.isSending,
                    awaitingAssistantReply: model.awaitingAssistantReply,
                    onSend: {
                        Task {
                            await transcriber.stopRecording()
                            await model.send()
                        }
                    },
                    transcriber: transcriber
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(palette.screenBackground)
                .onChange(of: transcriber.transcript) { _, newValue in
                    if case .recording = transcriber.state {
                        model.messageDraft = newValue
                    }
                }
            }
            .background(palette.screenBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .animation(.easeInOut(duration: 0.35), value: isEmpty)
            .onAppear {
                if assistantAnimationBaselineCount == nil, !model.messages.isEmpty {
                    assistantAnimationBaselineCount = model.messages.count
                }
                scheduleScrollToBottom(proxy, animated: false, reason: "onAppear")
            }
            .onChange(of: model.messages.isEmpty) { _, empty in
                if empty { assistantAnimationBaselineCount = nil }
            }
            .onChange(of: model.messages.count) { old, new in
                if assistantAnimationBaselineCount == nil, new > 0 {
                    let delta = new - old
                    if delta > 2 {
                        assistantAnimationBaselineCount = new
                    } else {
                        assistantAnimationBaselineCount = old
                    }
                }
                scheduleScrollToBottom(proxy, animated: true, reason: "messages.count")
            }
            .onChange(of: model.messages.last?.id) { _, _ in
                scheduleScrollToBottom(proxy, animated: true, reason: "messages.last.id")
            }
            .onChange(of: model.messages.last?.content) { _, _ in
                if !model.messages.isEmpty {
                    // Streaming updates: scroll without animation to avoid fighting `withAnimation` on every token.
                    scheduleScrollToBottom(proxy, animated: false, reason: "messages.last.content")
                }
            }
            .onChange(of: model.awaitingAssistantReply) { _, awaiting in
                if awaiting {
                    ChatUIDebugLogger.composerLockChanged(locked: true, reason: "ChatScreen.awaitingAssistantReply")
                    dismissChatKeyboard()
                }
            }
            .onChange(of: model.approvalState?.agenticSteps.count) { _, count in
                if let count, count > 0 {
                    ChatUIDebugLogger.agenticStepsVisible(count: count)
                }
            }
        }
    }
}

// MARK: - Assistant entrance motion

private struct AssistantMessageRevealModifier: ViewModifier {
    let shouldAnimate: Bool
    let reduceMotion: Bool

    @State private var revealed = false

    func body(content: Content) -> some View {
        let motion = shouldAnimate && !reduceMotion

        content
            .opacity(motion ? (revealed ? 1 : 0) : 1)
            .offset(y: motion ? (revealed ? 0 : 10) : 0)
            .scaleEffect(motion ? (revealed ? 1 : 0.98) : 1)
            .onAppear {
                guard motion else {
                    revealed = true
                    return
                }
                guard !revealed else { return }
                withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                    revealed = true
                }
            }
            .onChange(of: shouldAnimate) { _, animate in
                if !animate { revealed = true }
            }
    }
}

// MARK: - Message row

private struct MessageRow: View {
    let message: ChatService.ChatMessage
    @Bindable var readAloud: ReadAloudController
    /// When true, the assistant block uses a soft fade + slide (new reply only; see baseline in ``ChatScreen``).
    var animateAssistantInsertion: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isUser: Bool { message.role == "user" }
    private var palette: BudgeChatPalette { BudgeChatPalette(colorScheme: colorScheme) }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 36) }

            VStack(alignment: .leading, spacing: 0) {
                if isUser {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(palette.bodyText)
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(palette.userMessageBubbleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(palette.borderPrimary, lineWidth: 2)
                        )
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(ChatContentParser.parse(message.content)) { part in
                            switch part {
                            case .markdown(_, let md):
                                MarkdownView(text: md, style: .assistantMarkdown)
                            case .visualization(_, let spec):
                                VisualizationView(spec: spec)
                            }
                        }
                        AssistantMessageToolbar(
                            messageId: message.id,
                            rawText: message.content,
                            readAloud: readAloud
                        )
                    }
                    .padding(.vertical, 6)
                    .modifier(
                        AssistantMessageRevealModifier(shouldAnimate: animateAssistantInsertion, reduceMotion: reduceMotion)
                    )
                }
            }
            .frame(maxWidth: isUser ? 280 : .infinity, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 8) }
        }
    }
}

// MARK: - Agentic / approval

private struct AgenticProgressView: View {
    let steps: [ChatService.AgenticStep]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = BudgeChatPalette(colorScheme: colorScheme)
        VStack(alignment: .center, spacing: 6) {
            ForEach(steps) { step in
                HStack(spacing: 8) {
                    StepIcon(status: step.status)
                    Text(step.message)
                        .font(.subheadline)
                        .foregroundStyle(palette.bodyText.opacity(0.85))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StepIcon: View {
    let status: String

    var body: some View {
        Group {
            switch status {
            case "completed":
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case "failed":
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(.red)
            case "in_progress":
                PulsingDots()
            default:
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 10, height: 10)
            }
        }
        .frame(width: 16, height: 16)
    }
}

private struct PulsingDots: View {
    @State private var phase: Int = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 4, height: 4)
                    .opacity(phase == i ? 1.0 : 0.25)
            }
        }
        .onAppear {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = (phase + 1) % 3
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

private struct ApprovalCard: View {
    let approval: ChatService.ApprovalItem?
    let onAllow: (_ choice: String?) -> Void
    let onDeny: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = BudgeChatPalette(colorScheme: colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            Text(approval?.message ?? "Proceed with the requested changes?")
                .font(.subheadline)
                .foregroundStyle(palette.bodyText)

            HStack(spacing: 12) {
                Button("Deny") { onDeny() }
                    .buttonStyle(.bordered)

                Spacer()

                if approval?.needsTypeSelection == true {
                    Button("Expense") { onAllow("expense") }
                        .buttonStyle(.borderedProminent)
                    Button("Income") { onAllow("income") }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Allow") { onAllow(nil) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(14)
        .background(palette.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(palette.borderPrimary.opacity(0.5), lineWidth: 1)
        )
    }
}
