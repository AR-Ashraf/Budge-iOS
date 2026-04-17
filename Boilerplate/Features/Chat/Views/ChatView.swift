import SwiftUI

struct ChatView: View {
    @Environment(AuthService.self) private var authService
    @Environment(ChatService.self) private var chatService

    @State private var model: ChatViewModel?
    @State private var scrolledToBottom = true

    var body: some View {
        Group {
            if let model {
                ChatScreen(model: model)
            } else {
                ProgressView()
                    .task { await bootstrapIfPossible() }
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }

    @MainActor
    private func bootstrapIfPossible() async {
        guard let uid = authService.currentUser?.id else { return }
        // For now: single default chat per user. Later you can add chat list + chat creation.
        let chatId = "default"
        let vm = ChatViewModel(chatService: chatService, uid: uid, chatId: chatId)
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

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        // Agentic progress (server-driven via approvalStates[0].agenticSteps)
                        if let steps = model.approvalState?.agenticSteps, !steps.isEmpty {
                            AgenticProgressView(steps: steps)
                                .padding(.top, 12)
                        }

                        ForEach(model.messages) { m in
                            MessageBubble(
                                role: m.role,
                                text: m.content,
                                shouldAnimateAssistant: (m.role == "assistant") && model.shouldAnimateAssistantMessage(id: m.id),
                                onAssistantAnimationFinished: {
                                    model.markAnimated(id: m.id)
                                }
                            )
                                .id(m.id)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: model.messages.count) { _, _ in
                    // Auto-scroll to bottom for new assistant responses.
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Approval UI (server-owned)
            if let approval = model.approvalState, approval.awaitingApproval {
                ApprovalCard(
                    approval: approval.pendingApprovals.indices.contains(approval.currentApprovalIndex)
                    ? approval.pendingApprovals[approval.currentApprovalIndex]
                    : nil,
                    onAllow: { choice in Task { await model.approve(choice: choice) } },
                    onDeny: { Task { await model.deny() } }
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            InputBar(
                text: $model.messageDraft,
                isSending: model.isSending,
                onSend: { Task { await model.send() } }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.background)
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MessageBubble: View {
    let role: String
    let text: String
    let shouldAnimateAssistant: Bool
    let onAssistantAnimationFinished: () -> Void

    var isUser: Bool { role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                if !isUser, shouldAnimateAssistant {
                    TypingMarkdownView(fullText: text, charactersPerSecond: 70) {
                        onAssistantAnimationFinished()
                    }
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                } else {
                    ForEach(ChatContentParser.parse(text)) { part in
                        switch part {
                        case .markdown(_, let md):
                            MarkdownView(text: md)
                                .font(.body)
                                .foregroundStyle(isUser ? AppTheme.Colors.budgeGreenDarkText : AppTheme.Colors.textPrimary)
                        case .visualization(_, let spec):
                            VisualizationView(spec: spec)
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isUser ? AppTheme.Colors.budgeGreenPrimary : AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

private struct InputBar: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void
    @State private var transcriber = SpeechTranscriber()

    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask Anything…", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)

            Button {
                Task {
                    switch transcriber.state {
                    case .recording:
                        transcriber.stop()
                    default:
                        await transcriber.start()
                    }
                }
            } label: {
                Image(systemName: transcriber.state == .recording ? "mic.fill" : "mic")
            }
            .buttonStyle(.bordered)

            Button {
                onSend()
            } label: {
                Text("Send")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onChange(of: transcriber.transcript) { _, newValue in
            // Mirror web behavior: transcription fills the draft while recording.
            if transcriber.state == .recording {
                text = newValue
            }
        }
    }
}

private struct AgenticProgressView: View {
    let steps: [ChatService.AgenticStep]

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            ForEach(steps) { step in
                HStack(spacing: 8) {
                    StepIcon(status: step.status)
                    Text(step.message)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(approval?.message ?? "Proceed with the requested changes?")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

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
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

