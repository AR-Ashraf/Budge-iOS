import FirebaseFirestore
import Foundation
import SwiftUI

@Observable
final class ChatViewModel {
    @ObservationIgnored private var messagesListener: ListenerRegistration?
    @ObservationIgnored private var approvalListener: ListenerRegistration?

    private let chatService: ChatService
    private let onboarding: OnboardingService
    private let uid: String

    /// Matches web: new UUID when user starts a fresh thread from the header logo.
    private(set) var chatId: String

    var messages: [ChatService.ChatMessage] = []
    var approvalState: ChatService.ApprovalState?
    var messageDraft: String = ""
    var isSending: Bool = false

    /// After a successful user send, `true` until Firestore shows an assistant message as the latest message (clears keyboard lock / composer disable).
    private(set) var awaitingAssistantReply: Bool = false

    // MARK: - Finance header (currency pill)

    var headerCurrencyCode: String = "USD"
    var headerBalanceDisplay: String = "0"

    @ObservationIgnored private var financeHeaderTask: Task<Void, Never>?

    init(chatService: ChatService, onboarding: OnboardingService, uid: String, chatId: String = "default") {
        self.chatService = chatService
        self.onboarding = onboarding
        self.uid = uid
        self.chatId = chatId
    }

    deinit {
        messagesListener?.remove()
        approvalListener?.remove()
        financeHeaderTask?.cancel()
    }

    func start() {
        if messagesListener == nil {
            messagesListener = chatService.subscribeMessages(uid: uid, chatId: chatId) { [weak self] msgs in
                Task { @MainActor in
                    guard let self else { return }
                    let lastRole = msgs.last.map(\.role)
                    let suffix = msgs.last.map { String($0.id.suffix(6)) } ?? ""
                    ChatUIDebugLogger.messagesUpdated(count: msgs.count, lastRole: lastRole, lastIdSuffix: suffix)

                    self.messages = msgs
                    if self.awaitingAssistantReply, lastRole == "assistant" {
                        self.awaitingAssistantReply = false
                        ChatUIDebugLogger.assistantReplyCleared()
                    }
                }
            }
        }
        if approvalListener == nil {
            approvalListener = chatService.subscribeApprovalState(uid: uid, chatId: chatId) { [weak self] state in
                Task { @MainActor in
                    self?.approvalState = state
                }
            }
        }

        financeHeaderTask?.cancel()
        financeHeaderTask = Task { [weak self] in
            await self?.refreshFinanceHeader()
        }
    }

    /// New chat thread (web: new `chatId` + empty list).
    func beginNewChat() {
        messagesListener?.remove()
        approvalListener?.remove()
        messagesListener = nil
        approvalListener = nil

        chatId = UUID().uuidString
        messages = []
        messageDraft = ""
        approvalState = nil
        awaitingAssistantReply = false
        ChatUIDebugLogger.awaitingAssistantChanged(false)
        start()
        Task { await refreshFinanceHeader() }
    }

    @MainActor
    func refreshFinanceHeader() async {
        do {
            let profile = try await onboarding.fetchUserProfile(uid: uid)
            if let c = profile["currency"] as? String, !c.isEmpty {
                headerCurrencyCode = c.uppercased()
            }
            let snap = try await onboarding.fetchFinanceSnapshot()
            let fromAccounts = snap.accounts.reduce(0.0) { $0 + ($1.currentBalance ?? 0) }
            let total = snap.currentBalance ?? fromAccounts
            headerBalanceDisplay = Self.formatGroupedNumber(total)
        } catch {
            headerBalanceDisplay = "0"
        }
    }

    private static func formatGroupedNumber(_ value: Double) -> String {
        let n = NSNumber(value: value)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f.string(from: n) ?? String(format: "%.0f", value)
    }

    @MainActor
    func send() async {
        let text = messageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        ChatUIDebugLogger.sendStarted(textLength: text.count)
        isSending = true
        messageDraft = ""
        defer { isSending = false }
        do {
            try await chatService.sendUserMessage(uid: uid, chatId: chatId, text: text)
            awaitingAssistantReply = true
            ChatUIDebugLogger.awaitingAssistantChanged(true)
            await refreshFinanceHeader()
            ChatUIDebugLogger.sendFinished(success: true)
        } catch {
            messageDraft = text
            awaitingAssistantReply = false
            ChatUIDebugLogger.sendFinished(success: false)
        }
    }

    func approve(choice: String? = nil) async {
        do {
            try await chatService.resolveLatestApproval(uid: uid, chatId: chatId, approved: true, choice: choice)
        } catch {}
    }

    func deny() async {
        do {
            try await chatService.resolveLatestApproval(uid: uid, chatId: chatId, approved: false)
        } catch {}
    }
}
