import Foundation

/// The part of one session that counts as a state change: its status and, when waiting, what it waits for.
public struct SessionSignature: Sendable, Equatable {
    public let sessionId: String
    public let status: SessionStatus
    public let waitingFor: String?

    public init(sessionId: String, status: SessionStatus, waitingFor: String?) {
        self.sessionId = sessionId
        self.status = status
        self.waitingFor = waitingFor
    }

    public init(_ session: Session) {
        self.init(sessionId: session.sessionId, status: session.status, waitingFor: session.waitingFor)
    }
}

public struct StateSignature: Sendable, Equatable {
    public let sessions: [SessionSignature]
    public let hiddenSessionCount: Int

    public init(sessions: [SessionSignature], hiddenSessionCount: Int) {
        self.sessions = sessions
        self.hiddenSessionCount = hiddenSessionCount
    }
}

public enum StateChange {
    /// Spec §4.6: auto-dim's quiet clock restarts on a session state change only — not on a moving context
    /// percentage, a new cost, fresher limits or the stale flag flipping.
    public static func sessionSignature(_ state: PanelState) -> StateSignature {
        StateSignature(sessions: state.allSessions.map(SessionSignature.init), hiddenSessionCount: state.hiddenSessionCount)
    }
}
