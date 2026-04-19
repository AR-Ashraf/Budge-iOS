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

    /// Per-send chat mode (default `.ask`). Each user message is stamped with the active mode at send time
    /// so the Firebase Functions pipeline can route Ask / Agent / Plan strategies independently.
    var chatMode: ChatMode = .ask

    /// After a successful user send, `true` until Firestore shows an assistant message as the latest message (clears keyboard lock / composer disable).
    private(set) var awaitingAssistantReply: Bool = false

    // MARK: - Finance header (currency pill)

    var headerCurrencyCode: String = "USD"
    var headerBalanceDisplay: String = "0"
    /// True only during the **first** profile + `finance_getSnapshot` fetch for this screen session (no spinner on send / background refresh).
    var headerBalanceLoading: Bool = false

    @ObservationIgnored private var financeHeaderTask: Task<Void, Never>?
    /// Set synchronously on first `refreshFinanceHeader` entry so overlapping calls (e.g. send while initial fetch runs) never toggle the header spinner.
    @ObservationIgnored private var financeHeaderInitialFetchClaimed = false

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

                    #if DEBUG
                    guard let state else { return }
                    if let pending = state.pendingClassifiedJson, !pending.isEmpty {
                        print("🧠 [BudgeChat] pendingClassified\n\(pending)")
                    }
                    if let debug = state.serverDebugJson, !debug.isEmpty {
                        print("☁️ [BudgeChat] serverDebug\n\(debug)")
                    }
                    #endif
                }
            }
        }

        Task { await refreshChatThreads() }

        financeHeaderTask?.cancel()
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
        chatMode = .ask
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
        chatMode = .ask
        start()
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
        let showInitialSpinner = !financeHeaderInitialFetchClaimed
        financeHeaderInitialFetchClaimed = true
        if showInitialSpinner {
            headerBalanceLoading = true
        }
        defer {
            if showInitialSpinner {
                headerBalanceLoading = false
            }
        }
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
            try await chatService.sendUserMessage(uid: uid, chatId: chatId, text: text, mode: chatMode.rawValue)
            await refreshChatThreads()
            await refreshFinanceHeader()
        } catch {
            messageDraft = text
            awaitingAssistantReply = false
        }
    }

    func approve(choice: String? = nil) async {
        // Optimistically hide only the modal (by clearing `pendingApprovals`) so the existing
        // `agenticSteps` snapshot keeps rendering while the server transitions to execution steps.
        // Do NOT nil out `approvalState` entirely — losing the Firestore steps snapshot causes
        // the view to fall back to the local "Understanding your request" placeholder.
        if let current = approvalState {
            approvalState = ChatService.ApprovalState(
                awaitingApproval: false,
                pendingApprovals: [],
                currentApprovalIndex: 0,
                agenticSteps: current.agenticSteps,
                serverDebugJson: current.serverDebugJson,
                pendingClassifiedJson: current.pendingClassifiedJson
            )
        }
        #if DEBUG
        print("✅ [BudgeChat] approve tapped chatId=\(chatId) choice=\(choice ?? "nil")")
        #endif
        do {
            try await chatService.resolveLatestApproval(uid: uid, chatId: chatId, approved: true, choice: choice)
            #if DEBUG
            print("✅ [BudgeChat] approve write succeeded chatId=\(chatId)")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ [BudgeChat] approve failed: \(error)")
            #endif
        }
    }

    func deny(topic: String? = nil) async {
        // Optimistically hide the modal. Server (`onChatApprovalDecisionUpdated`, `denied` branch)
        // is responsible for: (a) appending the "Gotcha…" assistant message, (b) clearing
        // `approvalStates` awaiting flag. Keep the snapshot so we don't flash a stale interstitial.
        if let current = approvalState {
            approvalState = ChatService.ApprovalState(
                awaitingApproval: false,
                pendingApprovals: [],
                currentApprovalIndex: 0,
                agenticSteps: current.agenticSteps,
                serverDebugJson: current.serverDebugJson,
                pendingClassifiedJson: current.pendingClassifiedJson
            )
        }
        #if DEBUG
        print("⛔️ [BudgeChat] deny tapped chatId=\(chatId) topic=\(topic ?? "nil")")
        #endif
        do {
            try await chatService.resolveLatestApproval(uid: uid, chatId: chatId, approved: false)
            #if DEBUG
            print("⛔️ [BudgeChat] deny write succeeded chatId=\(chatId)")
            #endif
        } catch {
            // If the server write itself failed, re-open the modal so the user isn't stranded.
            awaitingAssistantReply = false
            #if DEBUG
            print("⚠️ [BudgeChat] deny failed: \(error)")
            #endif
        }
    }
}
