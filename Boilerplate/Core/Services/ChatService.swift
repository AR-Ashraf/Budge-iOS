import Foundation
import FirebaseFirestore

@Observable
final class ChatService {
    private var db: Firestore { Firestore.firestore() }

    // MARK: - Debug JSON helpers (Timestamp-safe)

    private static func jsonSafe(_ value: Any?) -> Any {
        guard let value else { return NSNull() }

        // Firestore Timestamp → ISO8601 string
        if let ts = value as? Timestamp {
            return ISO8601DateFormatter().string(from: ts.dateValue())
        }
        if let date = value as? Date {
            return ISO8601DateFormatter().string(from: date)
        }

        // Primitive Foundation JSON types
        if value is NSNull { return value }
        if value is NSString || value is NSNumber { return value }
        if let s = value as? String { return s }
        if let b = value as? Bool { return b }
        if let i = value as? Int { return i }
        if let d = value as? Double { return d }

        // Arrays / dictionaries
        if let arr = value as? [Any] {
            return arr.map { jsonSafe($0) }
        }
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            out.reserveCapacity(dict.count)
            for (k, v) in dict {
                out[k] = jsonSafe(v)
            }
            return out
        }

        // Fallback: string description (prevents crashes)
        return String(describing: value)
    }

    private static func stringifyJson(_ value: Any?) -> String? {
        let safe = jsonSafe(value)
        guard JSONSerialization.isValidJSONObject(safe),
              let data = try? JSONSerialization.data(withJSONObject: safe, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8)
        else { return nil }
        return str
    }

    // MARK: - Types

    struct ChatThread: Identifiable, Equatable {
        let id: String
        let title: String
        let timestamp: Date?
    }

    struct ChatMessage: Identifiable, Equatable {
        let id: String
        let role: String
        let content: String
        let timestamp: Date?
        /// Chat mode ("ask" | "agent" | "plan") the user sent this message in. Server reads this to pick the pipeline.
        let mode: String?
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
        /// Debug payload from the server pipeline (for Xcode console).
        let serverDebugJson: String?
        /// The raw Phase-1 JSON the server stored on the chat doc for this turn (for inspection).
        let pendingClassifiedJson: String?
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

    func fetchChatThreads(uid: String) async throws -> [ChatThread] {
        let q = db.collection("chats")
            .document(uid)
            .collection("userChats")
            .order(by: "timestamp", descending: true)

        let snap = try await q.getDocuments()
        return snap.documents.map { doc in
            let data = doc.data()
            let title = String(data["title"] as? String ?? "Chat")
            let ts = (data["timestamp"] as? Timestamp)?.dateValue()
            return ChatThread(id: doc.documentID, title: title, timestamp: ts)
        }
    }

    func updateChatTitle(uid: String, chatId: String, newTitle: String) async throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await chatRef(uid: uid, chatId: chatId).setData(["title": trimmed], merge: true)
    }

    func deleteChat(uid: String, chatId: String) async throws {
        try await chatRef(uid: uid, chatId: chatId).delete()
    }

    /// Seeds the chat doc before the first message. The **canonical title** is set server-side by the
    /// `onChatUserMessageCreated` Cloud Function (DeepSeek), which overwrites this placeholder after the first user message.
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

    /// Writes a user message with the active chat mode (`ask` | `agent` | `plan`). The Firebase Functions
    /// `onChatUserMessageCreated` trigger reads `mode` to route to the matching pipeline.
    func sendUserMessage(uid: String, chatId: String, text: String, mode: String = "ask") async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try await ensureChatDocument(uid: uid, chatId: chatId, seedTitleFrom: trimmed)

        let normalizedMode: String = {
            switch mode {
            case "ask", "agent", "plan": return mode
            default: return "ask"
            }
        }()

        let doc = messagesRef(uid: uid, chatId: chatId).document()
        try await doc.setData([
            "role": "user",
            "content": trimmed,
            "mode": normalizedMode,
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
                        timestamp: ts,
                        mode: data["mode"] as? String
                    )
                }
                onChange(messages)
            }
    }

    func subscribeApprovalState(uid: String, chatId: String, onChange: @escaping (ApprovalState?) -> Void) -> ListenerRegistration {
        chatRef(uid: uid, chatId: chatId).addSnapshotListener { snap, _ in
            guard let snap, snap.exists else { onChange(nil); return }
            let data = snap.data() ?? [:]
            let approvalStates = data["approvalStates"] as? [[String: Any]]
            let first = approvalStates?.first
            let serverDebug = data["serverDebug"] as? [String: Any]
            let serverDebugJson: String? = Self.stringifyJson(serverDebug)

            if first == nil {
                onChange(nil)
                return
            }
            guard let first else { return }

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

            let pendingClassified = first["pendingClassified"]
            let pendingClassifiedJson: String? = Self.stringifyJson(pendingClassified)

            onChange(
                ApprovalState(
                    awaitingApproval: awaiting,
                    pendingApprovals: pendingApprovals,
                    currentApprovalIndex: idx,
                    agenticSteps: steps,
                    serverDebugJson: serverDebugJson,
                    pendingClassifiedJson: pendingClassifiedJson
                )
            )
        }
    }

    // MARK: - Approvals

    func resolveLatestApproval(uid: String, chatId: String, approved: Bool, choice: String? = nil) async throws {
        // Web (`useChatHandler` approve/deny) performs API work then updates the **chat** document’s `approvalStates`
        // and messages. iOS uses the lightweight **approvals** subcollection contract below; parity with web’s full
        // client-side approval pipeline is server-dependent—extend here if product requires the same writes as web.
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

