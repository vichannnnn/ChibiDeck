import Foundation

public enum SessionKind: String, Sendable, Equatable {
    case interactive
    case background
}

public enum SessionStatus: String, Sendable, Equatable, CaseIterable {
    case waiting, blocked, busy, shell, idle, unknown

    /// Normalises the strings Claude Code emits (`status` for interactive sessions,
    /// `state` for background agents) into one enum. Unknown strings map to `.unknown`.
    public init(claudeString raw: String?) {
        switch raw?.lowercased() {
        case "waiting": self = .waiting
        case "blocked": self = .blocked
        case "busy", "running", "working": self = .busy
        case "shell": self = .shell
        case "idle", "done", "completed": self = .idle
        default: self = .unknown
        }
    }

    public var needsAttention: Bool { self == .waiting || self == .blocked }
    public var isActive: Bool { self == .busy || self == .shell }

    /// Spec §4.2 order: waiting → blocked → busy → shell → idle → unknown.
    public var sortRank: Int {
        switch self {
        case .waiting: 0
        case .blocked: 1
        case .busy: 2
        case .shell: 3
        case .idle: 4
        case .unknown: 5
        }
    }
}

public struct Session: Sendable, Equatable, Identifiable {
    public var id: String { sessionId }
    public let sessionId: String
    public let name: String
    public let cwd: String
    public let pid: Int?
    public let kind: SessionKind
    public var status: SessionStatus
    public var waitingFor: String?
    public let startedAt: Date
    public var statusUpdatedAt: Date?
    /// The listing's own `id` for a background agent — the name of its `~/.claude/jobs/<id>` folder (spec 2026-09-07 §3.1).
    public let jobId: String?

    public init(sessionId: String, name: String, cwd: String, pid: Int?, kind: SessionKind,
                status: SessionStatus, waitingFor: String? = nil, startedAt: Date,
                statusUpdatedAt: Date? = nil, jobId: String? = nil) {
        self.sessionId = sessionId
        self.name = name
        self.cwd = cwd
        self.pid = pid
        self.kind = kind
        self.status = status
        self.waitingFor = waitingFor
        self.startedAt = startedAt
        self.statusUpdatedAt = statusUpdatedAt
        self.jobId = jobId
    }

    public func elapsed(at now: Date) -> TimeInterval { max(0, now.timeIntervalSince(startedAt)) }
}
