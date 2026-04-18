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
    @State private var showSidebar: Bool = false
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
    /// Merges Firestore `agenticSteps` with a local classify row. Suppresses **stale** snapshots where every step is
    /// still `completed`/`failed` from the **previous** turn (Firestore often delivers that briefly before the new pipeline writes).
    private func effectiveAgenticSteps(for model: ChatViewModel) -> [ChatService.AgenticStep]? {
        let fs = model.approvalState?.agenticSteps
        let awaiting = model.awaitingAssistantReply
        let lastIsUser = model.messages.last?.role == "user"
        let awaitingUserTurn = awaiting && lastIsUser
        let optimisticClassify: [ChatService.AgenticStep] = [
            ChatService.AgenticStep(
                id: "classify",
                message: "Understanding your request",
                status: "in_progress"
            ),
        ]

        if let steps = fs, !steps.isEmpty {
            if Self.firestoreAgenticLooksStaleFromPriorTurn(steps: steps) {
                if awaitingUserTurn { return optimisticClassify }
                if awaiting, !lastIsUser { return nil }
                return steps
            }
            return steps
        }

        if awaitingUserTurn {
            return optimisticClassify
        }
        return nil
    }

    /// Prior-turn pipeline often leaves all steps terminal until the next `updateAgenticStepsInChatDoc` — treat as stale while awaiting a reply for the latest user bubble.
    private static func firestoreAgenticLooksStaleFromPriorTurn(steps: [ChatService.AgenticStep]) -> Bool {
        steps.allSatisfy { $0.status == "completed" || $0.status == "failed" }
    }

    private func scheduleScrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        scrollCoalesceToken += 1
        let token = scrollCoalesceToken
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard token == scrollCoalesceToken else {
                return
            }
            if animated {
                withAnimation(.easeOut(duration: 0.28)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    /// Last index of a user message in the thread (for anchoring agentic / approval below that turn).
    private static func lastUserMessageIndex(in messages: [ChatService.ChatMessage]) -> Int? {
        for index in messages.indices.reversed() where messages[index].role == "user" {
            return index
        }
        return nil
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                VStack(spacing: 0) {
                    ChatChromeTopBar(
                        currencyCode: model.headerCurrencyCode,
                        balanceText: model.headerBalanceDisplay,
                        onLogoTap: { model.beginNewChat() },
                        onCurrencyTap: {
                            Task { await model.refreshFinanceHeader() }
                        },
                        onMenuTap: { showSidebar = true }
                    )
                    .simultaneousGesture(TapGesture().onEnded { dismissChatKeyboard() })

                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                // Anchor for scroll offset KVO (see ``ChatScrollOffsetReader``).
                                Color.clear
                                    .frame(width: 1, height: 1)
                                    .background(
                                        ChatScrollOffsetReader { distance in
                                            scrollDistanceFromBottom = distance
                                        }
                                    )

                                // `VStack` (not `LazyVStack`) so agentic rows under the last user bubble keep stable Y positions
                                // when Firestore appends steps; LazyVStack remeasured siblings and caused visible jumps.
                                VStack(alignment: .leading, spacing: 12) {
                                    if isEmpty {
                                        ChatWelcomeHero()
                                            .frame(maxWidth: .infinity)
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                    }

                                    let msgs = model.messages
                                    let lastUserIdx = Self.lastUserMessageIndex(in: msgs)

                                    ForEach(Array(msgs.enumerated()), id: \.element.id) { index, m in
                                        let animateAssistantInsertion =
                                            m.role == "assistant"
                                            && m.id == msgs.last?.id
                                            && msgs.count > (assistantAnimationBaselineCount ?? 0)
                                        MessageRow(
                                            message: m,
                                            readAloud: readAloud,
                                            animateAssistantInsertion: animateAssistantInsertion
                                        )
                                        .id(m.id)

                                        if index == lastUserIdx {
                                            ChatTurnInterstitialView(
                                                approval: model.approvalState,
                                                agenticSteps: effectiveAgenticSteps(for: model),
                                                lastMessageRole: msgs.last?.role,
                                                onAllow: { choice in Task { await model.approve(choice: choice) } },
                                                onDeny: { Task { await model.deny() } },
                                                onDismissKeyboard: dismissChatKeyboard
                                            )
                                            .id("interstitial-after-\(m.id)")
                                            .transaction { $0.animation = nil }
                                        }
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.screenBackground.ignoresSafeArea())

                ChatSidebarDrawer(
                    visible: $showSidebar,
                    model: model,
                    onDismissKeyboard: dismissChatKeyboard
                )
                .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .animation(.easeInOut(duration: 0.35), value: isEmpty)
            .onAppear {
                if assistantAnimationBaselineCount == nil, !model.messages.isEmpty {
                    assistantAnimationBaselineCount = model.messages.count
                }
                scheduleScrollToBottom(proxy, animated: false)
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
                // While the server pipeline is running, animated scroll fights agentic layout and reads as vertical flicker.
                scheduleScrollToBottom(proxy, animated: !model.awaitingAssistantReply)
            }
            .onChange(of: model.messages.last?.id) { _, _ in
                scheduleScrollToBottom(proxy, animated: !model.awaitingAssistantReply)
            }
            .onChange(of: model.messages.last?.content) { _, _ in
                if !model.messages.isEmpty {
                    // Streaming updates: scroll without animation to avoid fighting `withAnimation` on every token.
                    scheduleScrollToBottom(proxy, animated: false)
                }
            }
            .onChange(of: model.awaitingAssistantReply) { _, awaiting in
                if awaiting {
                    dismissChatKeyboard()
                }
            }
        }
    }
}

// MARK: - Inline agentic + approval (after last user message)

/// Firestore-driven approval and agentic steps, shown **below the latest user bubble** (web `ChatSection` order: approval then agentic). Agentic hides while the latest message is an assistant reply.
private struct ChatTurnInterstitialView: View {
    let approval: ChatService.ApprovalState?
    /// Merged Firestore + optimistic classify row (see `ChatScreen.effectiveAgenticSteps`).
    let agenticSteps: [ChatService.AgenticStep]?
    let lastMessageRole: String?
    let onAllow: (String?) -> Void
    let onDeny: () -> Void
    let onDismissKeyboard: () -> Void

    private var currentApprovalItem: ChatService.ApprovalItem? {
        guard let approval, approval.awaitingApproval else { return nil }
        guard approval.pendingApprovals.indices.contains(approval.currentApprovalIndex) else { return nil }
        return approval.pendingApprovals[approval.currentApprovalIndex]
    }

    private var showApproval: Bool {
        approval?.awaitingApproval == true
    }

    private var showAgentic: Bool {
        guard let steps = agenticSteps, !steps.isEmpty else { return false }
        return lastMessageRole != "assistant"
    }

    var body: some View {
        Group {
            if showApproval || showAgentic {
                VStack(alignment: .leading, spacing: 12) {
                    if showApproval {
                        ApprovalCard(
                            approval: currentApprovalItem,
                            onAllow: onAllow,
                            onDeny: onDeny
                        )
                    }
                    if showAgentic, let steps = agenticSteps {
                        AgenticProgressView(steps: steps)
                            .padding(40)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
                .simultaneousGesture(TapGesture().onEnded { onDismissKeyboard() })
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

    /// One “current” row at a time: completed/failed history, then the first pending or in_progress row (matches web pacing + Firestore snapshots).
    private var visibleSteps: [ChatService.AgenticStep] {
        Self.visibleAgenticSteps(steps)
    }

    private static func visibleAgenticSteps(_ steps: [ChatService.AgenticStep]) -> [ChatService.AgenticStep] {
        guard !steps.isEmpty else { return [] }
        var end = 0
        while end < steps.count && (steps[end].status == "completed" || steps[end].status == "failed") {
            end += 1
        }
        if end < steps.count {
            return Array(steps[0 ... end])
        }
        return steps
    }

    var body: some View {
        let palette = BudgeChatPalette(colorScheme: colorScheme)
        return VStack(alignment: .center, spacing: 6) {
            ForEach(visibleSteps) { step in
                HStack(alignment: .center, spacing: 8) {
                    StepIcon(status: step.status)
                    Text(step.message)
                        .font(.subheadline)
                        .foregroundStyle(textColor(for: step.status, palette: palette))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .opacity(rowOpacity(for: step.status))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
        // Keep step rows from inheriting implicit layout animations when Firestore updates statuses.
        .animation(nil, value: steps.map { "\($0.id):\($0.status)" }.joined(separator: "|"))
    }

    private func rowOpacity(for status: String) -> Double {
        switch status {
        case "in_progress": return 0.8
        case "pending": return 0.6
        default: return 1
        }
    }

    private func textColor(for status: String, palette: BudgeChatPalette) -> Color {
        switch status {
        case "completed": return .green
        case "failed": return .red
        case "in_progress": return palette.bodyText
        default: return palette.bodyText.opacity(0.72)
        }
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
