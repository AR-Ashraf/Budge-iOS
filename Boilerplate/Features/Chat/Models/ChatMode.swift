import Foundation

/// Chat interaction modes — mirrors Cursor's mode selector.
///
/// Selected per user message and persisted on the Firestore message document under `mode`.
/// The Firebase Functions chat pipeline routes each mode to a different prompt strategy:
/// - `ask`: CFO-level Q&A, no Firestore writes. Action requests are deflected to Agent mode.
/// - `agent`: Two-phase agentic flow (classify → execute with optional approval → reply).
/// - `plan`: CFO-level financial planner with rich markdown tables and chart JSON blocks.
enum ChatMode: String, CaseIterable, Identifiable, Codable {
    case ask
    case agent
    case plan

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ask: return "Ask"
        case .agent: return "Agent"
        case .plan: return "Plan"
        }
    }

    /// SF Symbol name for the mode chip.
    var sfSymbol: String {
        switch self {
        case .ask: return "bubble.left.and.bubble.right"
        case .agent: return "sparkles"
        case .plan: return "chart.line.uptrend.xyaxis"
        }
    }

    /// Short one-line description shown under each menu item.
    var menuSubtitle: String {
        switch self {
        case .ask:
            return "Quick financial Q&A"
        case .agent:
            return "Take actions on your budget"
        case .plan:
            return "Long-term planning & charts"
        }
    }
}
