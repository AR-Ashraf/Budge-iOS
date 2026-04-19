import FirebaseFirestore
import Foundation
import SwiftUI

@Observable
final class ChatViewModel {
    @ObservationIgnored private var messagesListener: ListenerRegistration?
    @ObservationIgnored private var approvalListener: ListenerRegistration?

    private let chatService: ChatService
    private let onboarding: OnboardingService
    let uid: String

    /// Matches web: new UUID when user starts a fresh thread from the header logo.
    private(set) var chatId: String

    var messages: [ChatService.ChatMessage] = []
    var approvalState: ChatService.ApprovalState?
    var messageDraft: String = ""
    var isSending: Bool = false
    var chatThreads: [ChatService.ChatThread] = []
    var chatThreadsLoading: Bool = false

    /// After a successful user send, `true` until Firestore shows an assistant message as the latest message (clears keyboard lock / composer disable).
    private(set) var awaitingAssistantReply: Bool = false

    // MARK: - Finance header (currency pill)

    var headerCurrencyCode: String = "USD"
    var headerBalanceDisplay: String = "0"
    /// True while loading profile + `finance_getSnapshot` for user-level balances.
    var headerBalanceLoading: Bool = false

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

                    self.messages = msgs
                    if self.awaitingAssistantReply, lastRole == "assistant" {
                        self.awaitingAssistantReply = false
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

        Task { await refreshChatThreads() }

        financeHeaderTask?.cancel()
        headerBalanceLoading = true
        financeHeaderTask = Task { [weak self] in
            await self?.refreshFinanceHeader()
        }
    }

    func openChat(chatId: String) {
        guard self.chatId != chatId else { return }
        messagesListener?.remove()
        approvalListener?.remove()
        messagesListener = nil
        approvalListener = nil

        self.chatId = chatId
        messages = []
        messageDraft = ""
        approvalState = nil
        awaitingAssistantReply = false
        start()
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
        start()
        Task { await refreshFinanceHeader() }
    }

    @MainActor
    func refreshChatThreads() async {
        guard !chatThreadsLoading else { return }
        chatThreadsLoading = true
        defer { chatThreadsLoading = false }
        do {
            chatThreads = try await chatService.fetchChatThreads(uid: uid)
        } catch {
            chatThreads = []
        }
    }

    @MainActor
    func renameChatThread(chatId: String, newTitle: String) async {
        do {
            try await chatService.updateChatTitle(uid: uid, chatId: chatId, newTitle: newTitle)
        } catch {}
        await refreshChatThreads()
    }

    @MainActor
    func deleteChatThread(chatId: String) async {
        do {
            try await chatService.deleteChat(uid: uid, chatId: chatId)
        } catch {}
        if self.chatId == chatId {
            beginNewChat()
        }
        await refreshChatThreads()
    }

    @MainActor
    func refreshFinanceHeader() async {
        headerBalanceLoading = true
        defer { headerBalanceLoading = false }
        do {
            async let profileTask = onboarding.fetchUserProfile(uid: uid)
            async let snapTask = onboarding.fetchFinanceSnapshot()
            let profile = try await profileTask
            let snap = try await snapTask

            // Icon / label: `users/{uid}.currency` (kept in sync with main account currency on the server / web).
            if let c = profile["currency"] as? String,
               !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                headerCurrencyCode = c.uppercased()
            } else {
                headerCurrencyCode = "USD"
            }

            // Amount: `users/{uid}.currentBalance` — server sum of all account balances in user currency (see `finance_getSnapshot` + triggers).
            let total = snap.currentBalance ?? 0
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
        isSending = true
        messageDraft = ""
        awaitingAssistantReply = true
        defer { isSending = false }
        do {
            try await chatService.sendUserMessage(uid: uid, chatId: chatId, text: text)
            await refreshChatThreads()
            await refreshFinanceHeader()
        } catch {
            messageDraft = text
            awaitingAssistantReply = false
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
