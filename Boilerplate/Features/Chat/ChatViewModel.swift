import Foundation
import FirebaseFirestore
import SwiftUI

@Observable
final class ChatViewModel {
    @ObservationIgnored private var messagesListener: ListenerRegistration?
    @ObservationIgnored private var approvalListener: ListenerRegistration?

    private let chatService: ChatService
    private let uid: String

    let chatId: String

    var messages: [ChatService.ChatMessage] = []
    var approvalState: ChatService.ApprovalState?
    var messageDraft: String = ""
    var isSending: Bool = false
    var animatedAssistantMessageIds: Set<String> = []

    init(chatService: ChatService, uid: String, chatId: String) {
        self.chatService = chatService
        self.uid = uid
        self.chatId = chatId
    }

    deinit {
        messagesListener?.remove()
        approvalListener?.remove()
    }

    func start() {
        if messagesListener == nil {
            messagesListener = chatService.subscribeMessages(uid: uid, chatId: chatId) { [weak self] msgs in
                Task { @MainActor in
                    self?.messages = msgs
                    // Mark existing assistant messages as already animated, except the newest one.
                    let assistantIds = msgs.filter { $0.role == "assistant" }.map { $0.id }
                    if let last = assistantIds.last {
                        var set = self?.animatedAssistantMessageIds ?? []
                        for id in assistantIds.dropLast() { set.insert(id) }
                        self?.animatedAssistantMessageIds = set
                        // Leave `last` out so it can animate once.
                    } else {
                        self?.animatedAssistantMessageIds = []
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
    }

    @MainActor
    func send() async {
        let text = messageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        messageDraft = ""
        defer { isSending = false }
        do {
            try await chatService.sendUserMessage(uid: uid, chatId: chatId, text: text)
        } catch {
            // If send fails, restore draft so user can retry
            messageDraft = text
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

    func shouldAnimateAssistantMessage(id: String) -> Bool {
        !animatedAssistantMessageIds.contains(id)
    }

    func markAnimated(id: String) {
        animatedAssistantMessageIds.insert(id)
    }
}

