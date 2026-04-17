import Foundation
import FirebaseFirestore

@Observable
final class ChatService {
    private var db: Firestore { Firestore.firestore() }

    // MARK: - Types

    struct ChatMessage: Identifiable, Equatable {
        let id: String
        let role: String
        let content: String
        let timestamp: Date?
    }

    struct AgenticStep: Identifiable, Equatable {
        let id: String
        let message: String
        let status: String
    }

    struct ApprovalItem: Equatable {
        let kind: String
        let message: String
        let needsTypeSelection: Bool
    }

    struct ApprovalState: Equatable {
        let awaitingApproval: Bool
        let pendingApprovals: [ApprovalItem]
        let currentApprovalIndex: Int
        let agenticSteps: [AgenticStep]
    }

    struct ApprovalDecision {
        let id: String
        let status: String
    }

    // MARK: - Paths

    private func chatRef(uid: String, chatId: String) -> DocumentReference {
        db.collection("chats").document(uid).collection("userChats").document(chatId)
    }

    private func messagesRef(uid: String, chatId: String) -> CollectionReference {
        chatRef(uid: uid, chatId: chatId).collection("messages")
    }

    private func approvalsRef(uid: String, chatId: String) -> CollectionReference {
        chatRef(uid: uid, chatId: chatId).collection("approvals")
    }

    // MARK: - Messaging

    func ensureChatDocument(uid: String, chatId: String, seedTitleFrom text: String) async throws {
        let ref = chatRef(uid: uid, chatId: chatId)
        let snap = try await ref.getDocument()
        if snap.exists { return }

        let words = text.split(separator: " ").map(String.init)
        let fallbackTitle = words.prefix(4).joined(separator: " ")
        try await ref.setData([
            "title": fallbackTitle.isEmpty ? "Chat" : fallbackTitle,
            "timestamp": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func sendUserMessage(uid: String, chatId: String, text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try await ensureChatDocument(uid: uid, chatId: chatId, seedTitleFrom: trimmed)

        let doc = messagesRef(uid: uid, chatId: chatId).document()
        try await doc.setData([
            "role": "user",
            "content": trimmed,
            "timestamp": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // MARK: - Realtime subscriptions

    func subscribeMessages(uid: String, chatId: String, onChange: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration {
        messagesRef(uid: uid, chatId: chatId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, _ in
                guard let snapshot else { return }
                let messages: [ChatMessage] = snapshot.documents.map { doc in
                    let data = doc.data()
                    let ts = (data["timestamp"] as? Timestamp)?.dateValue()
                    return ChatMessage(
                        id: doc.documentID,
                        role: String(data["role"] as? String ?? ""),
                        content: String(data["content"] as? String ?? ""),
                        timestamp: ts
                    )
                }
                onChange(messages)
            }
    }

    func subscribeApprovalState(uid: String, chatId: String, onChange: @escaping (ApprovalState?) -> Void) -> ListenerRegistration {
        chatRef(uid: uid, chatId: chatId).addSnapshotListener { snap, _ in
            guard let snap, snap.exists else { onChange(nil); return }
            let data = snap.data() ?? [:]
            guard let approvalStates = data["approvalStates"] as? [[String: Any]], let first = approvalStates.first else {
                onChange(nil)
                return
            }

            let awaiting = (first["awaitingApproval"] as? Bool) ?? false
            let idx = (first["currentApprovalIndex"] as? Int) ?? 0

            let pendingApprovalsRaw = (first["pendingApprovals"] as? [[String: Any]]) ?? []
            let pendingApprovals: [ApprovalItem] = pendingApprovalsRaw.map { item in
                let kind = String(item["kind"] as? String ?? "")
                let message = String(item["message"] as? String ?? "")
                let payload = item["payload"] as? [String: Any]
                let needsTypeSelection = (payload?["needsTypeSelection"] as? Bool) ?? false
                return ApprovalItem(kind: kind, message: message, needsTypeSelection: needsTypeSelection)
            }

            let stepsRaw = (first["agenticSteps"] as? [[String: Any]]) ?? []
            let steps: [AgenticStep] = stepsRaw.map { s in
                AgenticStep(
                    id: String(s["id"] as? String ?? UUID().uuidString),
                    message: String(s["message"] as? String ?? ""),
                    status: String(s["status"] as? String ?? "pending")
                )
            }

            onChange(ApprovalState(awaitingApproval: awaiting, pendingApprovals: pendingApprovals, currentApprovalIndex: idx, agenticSteps: steps))
        }
    }

    // MARK: - Approvals

    func resolveLatestApproval(uid: String, chatId: String, approved: Bool, choice: String? = nil) async throws {
        // Server currently creates an approval decision doc; the simplest client contract:
        // resolve the most recent awaiting doc.
        let q = approvalsRef(uid: uid, chatId: chatId)
            .whereField("status", isEqualTo: "awaiting")
            .order(by: "createdAt", descending: true)
            .limit(to: 1)

        let snap = try await q.getDocuments()
        guard let doc = snap.documents.first else { return }

        var patch: [String: Any] = [
            "status": approved ? "approved" : "denied",
            "resolvedAt": FieldValue.serverTimestamp()
        ]
        if let choice { patch["choice"] = choice }

        try await doc.reference.setData(patch, merge: true)
    }
}

