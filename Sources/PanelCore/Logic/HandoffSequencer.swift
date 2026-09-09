import Foundation

/// Handoff §4: the state machine behind the menu's Handoff row. Pure: the app feeds it what it sees about the
/// session's pid (alive, session file, transcript) and carries out the command it hands back. One sequence per pid.
///
///   requested ──(same id, fenced reply newer than the request, its turn over)──▶ clearing ──(new id, not waiting)──▶ done
///       │ id changed / pid gone / 15 min after the `/handoff` record                │ pid gone / 30 s
///       │ (2 h if the record never appears)                                          ▼
///       ▼                                                                          failed
///     failed
///
/// Review 2026-09-10: the session file's `idle` is not the turn signal. Claude Code writes `busy` while any background
/// agent is alive and `shell` while a background Bash is alive, turn or no turn, so an orchestrating session never
/// reads `idle`. The turn end comes from the transcript (`handoffTurnEnded`), `idle` stays as the fallback, and only
/// `waiting` (a dialog) holds the paste. `/handoff` typed mid-turn is queued by Claude Code until the turn ends, so
/// the reply clock starts at the `/handoff` record's timestamp (`handoffRequestedAt`), not at the keystroke.
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

    /// One look at the pid: `kill(pid, 0)`, the `sessions/<pid>.json` record (nil fields when unreadable), and from
    /// the transcript the fenced reply after the last `/handoff` record with the timestamp of that assistant record,
    /// the timestamp of the `/handoff` record itself and whether a turn ended after the reply.
    public struct Observation: Equatable, Sendable {
        public var pidAlive: Bool
        public var sessionId: String?
        public var status: SessionStatus?
        public var handoffReply: String?
        public var handoffReplyAt: Date?
        public var handoffRequestedAt: Date?
        public var handoffTurnEnded: Bool

        public init(pidAlive: Bool, sessionId: String?, status: SessionStatus?, handoffReply: String?, handoffReplyAt: Date?,
                    handoffRequestedAt: Date? = nil, handoffTurnEnded: Bool = false) {
            self.pidAlive = pidAlive
            self.sessionId = sessionId
            self.status = status
            self.handoffReply = handoffReply
            self.handoffReplyAt = handoffReplyAt
            self.handoffRequestedAt = handoffRequestedAt
            self.handoffTurnEnded = handoffTurnEnded
        }
    }

    /// The skill reads the repo and writes a long block: 15 min from the moment the `/handoff` record appears.
    public static let replyTimeout: TimeInterval = 15 * 60
    /// A queued `/handoff` waits for the current turn; the user's orchestrating turns run half an hour and more.
    public static let queueTimeout: TimeInterval = 2 * 60 * 60
    /// The `/handoff` record can be written a moment before the typing script returns (`requestedAt`); an older
    /// record than this is a previous handoff.
    public static let requestSlack: TimeInterval = 30
    /// `/clear` is instant once typed; 30 s covers a slow tab search.
    public static let clearTimeout: TimeInterval = 30

    public let pid: Int
    /// The session id at the request; the reply is read from its transcript and its change is the clear signal.
    public let sessionId: String
    public let requestedAt: Date
    public private(set) var phase: Phase = .requested
    /// The block to paste, known from `clearing` on.
    public private(set) var block: String?
    /// The `/handoff` record has appeared in the transcript (the command ran rather than sat in the queue).
    public private(set) var landed = false
    private var landedAt: Date?
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
            if !landed, let at = o.handoffRequestedAt, at >= requestedAt - Self.requestSlack {
                landed = true
                landedAt = at
            }
            if o.sessionId == sessionId, o.status != .waiting, o.handoffTurnEnded || o.status == .idle,
               let reply = o.handoffReply, let at = o.handoffReplyAt, at >= requestedAt,
               let fenced = HandoffReply.block(in: reply) {                  // never `/clear` on a reply without a block
                block = fenced
                phase = .clearing
                clearRequestedAt = now
                return .typeClear
            }
            if let landedAt {
                if now.timeIntervalSince(landedAt) > Self.replyTimeout { return fail("no handoff reply") }
            } else if now.timeIntervalSince(requestedAt) > Self.queueTimeout {
                return fail("handoff never ran")
            }
            return nil
        case .clearing:
            guard o.pidAlive else { return fail("session exited") }
            if let id = o.sessionId, id != sessionId, o.status != .waiting, let block {
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
