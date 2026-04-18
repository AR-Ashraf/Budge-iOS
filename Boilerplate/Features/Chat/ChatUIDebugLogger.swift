import Foundation
import os

/// Debug tracing for chat scroll, focus, send, and assistant delivery (Console: subsystem `com.devscore.budge`, category `ChatUI`).
enum ChatUIDebugLogger {
    /// Uses `os.Logger` so it does not collide with app ``Logger`` in `Core/Logging/Logger.swift`.
    private static let osLog = os.Logger(subsystem: "com.devscore.budge", category: "ChatUI")

    static func scrollScheduled(reason: String, animated: Bool, token: UInt64) {
        osLog.debug("[scroll:scheduled] reason=\(reason) animated=\(animated) token=\(token)")
    }

    static func scrollCancelled(staleToken: UInt64, currentToken: UInt64) {
        osLog.debug("[scroll:cancelled] stale=\(staleToken) current=\(currentToken)")
    }

    static func scrollApplied(reason: String, animated: Bool, token: UInt64) {
        osLog.debug("[scroll:applied] reason=\(reason) animated=\(animated) token=\(token)")
    }

    static func fabScrollTapped() {
        osLog.debug("[scroll:fab] user tapped scroll-to-bottom")
    }

    static func inputFocusChanged(_ focused: Bool) {
        osLog.debug("[input:focus] TextField focused=\(focused)")
    }

    static func inputFocusSuppressedBecauseImplicit() {
        osLog.debug("[input:focus] suppressed implicit focus (tap field to type)")
    }

    static func composerLockChanged(locked: Bool, reason: String) {
        osLog.debug("[input:lock] locked=\(locked) reason=\(reason)")
    }

    static func sendStarted(textLength: Int) {
        osLog.debug("[send:started] draftLength=\(textLength)")
    }

    static func sendFinished(success: Bool) {
        osLog.debug("[send:finished] success=\(success)")
    }

    static func messagesUpdated(count: Int, lastRole: String?, lastIdSuffix: String) {
        let role = lastRole ?? "nil"
        osLog.debug("[messages:update] count=\(count) lastRole=\(role) lastIdSuffix=\(lastIdSuffix)")
    }

    static func awaitingAssistantChanged(_ awaiting: Bool) {
        osLog.debug("[state:awaitingAssistant] \(awaiting)")
    }

    static func assistantReplyCleared() {
        osLog.debug("[state:awaitingAssistant] cleared (assistant is latest)")
    }

    static func agenticStepsVisible(count: Int) {
        osLog.debug("[agentic:steps] count=\(count)")
    }
}
