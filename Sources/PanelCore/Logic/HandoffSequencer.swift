import Foundation

/// Handoff §4: the state machine behind the menu's Handoff row. Pure: the app feeds it what it sees about the
/// session's pid (alive, session file, transcript) and carries out the command it hands back. One sequence per pid.
///
///   requested ──(same id idle + reply newer than the request)──▶ clearing ──(new id idle)──▶ done
///       │ id changed / pid gone / 15 min                            │ pid gone / 30 s
///       ▼                                                            ▼
///     failed                                                       failed
public struct HandoffSequencer: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        /// `/handoff` typed; waiting for the skill's reply.
        case requested
        /// `/clear` typed; waiting for the session file to carry a new session id.
        case clearing
        case done
        case failed(String)
    }

    /// What the app must do next. `typeClear` and `paste` are Terminal actions; `fail` carries the toast text.
    public enum Command: Equatable, Sendable {
        case typeClear
        case paste(String)
        case fail(String)
    }

    /// One look at the pid: `kill(pid, 0)`, the `sessions/<pid>.json` record (nil fields when unreadable), and the
    /// transcript's fenced reply after the last `/handoff` record with the timestamp of that assistant record.
    public struct Observation: Equatable, Sendable {
        public var pidAlive: Bool
        public var sessionId: String?
        public var status: SessionStatus?
        public var handoffReply: String?
        public var handoffReplyAt: Date?

        public init(pidAlive: Bool, sessionId: String?, status: SessionStatus?, handoffReply: String?, handoffReplyAt: Date?) {
            self.pidAlive = pidAlive
            self.sessionId = sessionId
            self.status = status
            self.handoffReply = handoffReply
            self.handoffReplyAt = handoffReplyAt
        }
    }

    /// The skill reads the repo and writes a long block; queued behind a busy turn it can take a while.
    public static let replyTimeout: TimeInterval = 15 * 60
    /// `/clear` is instant once typed; 30 s covers a slow tab search.
    public static let clearTimeout: TimeInterval = 30

    public let pid: Int
    /// The session id at the request; the reply is read from its transcript and its change is the clear signal.
    public let sessionId: String
    public let requestedAt: Date
    public private(set) var phase: Phase = .requested
    /// The block to paste, known from `clearing` on.
    public private(set) var block: String?
    private var clearRequestedAt: Date?

    public init(pid: Int, sessionId: String, requestedAt: Date) {
        self.pid = pid
        self.sessionId = sessionId
        self.requestedAt = requestedAt
    }

    public var isActive: Bool { phase == .requested || phase == .clearing }

    public mutating func observe(_ o: Observation, now: Date) -> Command? {
        switch phase {
        case .requested:
            guard o.pidAlive else { return fail("session exited") }
            if let id = o.sessionId, id != sessionId { return fail("session cleared") }
            if o.sessionId == sessionId, o.status == .idle,
               let reply = o.handoffReply, let at = o.handoffReplyAt, at >= requestedAt,
               let fenced = HandoffReply.block(in: reply) {                  // never `/clear` on a reply without a block
                block = fenced
                phase = .clearing
                clearRequestedAt = now
                return .typeClear
            }
            if now.timeIntervalSince(requestedAt) > Self.replyTimeout { return fail("no handoff reply") }
            return nil
        case .clearing:
            guard o.pidAlive else { return fail("session exited") }
            if let id = o.sessionId, id != sessionId, o.status == .idle, let block {
                phase = .done
                return .paste(block)
            }
            if let since = clearRequestedAt, now.timeIntervalSince(since) > Self.clearTimeout { return fail("clear didn't happen") }
            return nil
        case .done, .failed:
            return nil
        }
    }

    /// The app could not carry out the last command (Terminal error): the sequence ends with that text.
    public mutating func abort(_ why: String) {
        guard isActive else { return }
        phase = .failed(why)
    }

    private mutating func fail(_ why: String) -> Command {
        phase = .failed(why)
        return .fail(why)
    }
}
