import Foundation

public enum TaskStatus: String, Sendable, Equatable {
    case completed, inProgress, pending

    public init(claudeString raw: String?) {
        switch raw?.lowercased() {
        case "completed", "done": self = .completed
        case "in_progress", "inprogress", "active": self = .inProgress
        default: self = .pending
        }
    }
}

public struct TaskItem: Sendable, Equatable, Identifiable {
    public let id: Int
    public let subject: String
    public let status: TaskStatus

    public init(id: Int, subject: String, status: TaskStatus) {
        self.id = id
        self.subject = subject
        self.status = status
    }
}

/// Everything the tile ring and the detail sheet need beyond the session list.
public struct SessionDetail: Sendable, Equatable {
    public var modelName: String?
    /// Plan 4 §5.1: the effort level from the statusline feed (`low` … `max`); nil until the feed reports one.
    public var effort: String?
    public var contextUsedTokens: Int?
    public var contextWindowSize: Int?
    /// 0…100. Nil when neither the feed nor a transcript gave a number.
    public var contextPercent: Double?
    /// True when `contextPercent` came from the transcript tail (spec §5.2 `~` marker).
    public var contextIsEstimate: Bool
    public var costUSD: Double?
    public var lastUserPrompt: String?
    public var lastAssistantText: String?
    public var tasks: [TaskItem]
    public var branch: String?
    public var lastActivity: Date?
    /// Background agents only (spec 2026-09-07 §2.5): the job file's `suggestedReply` and `state`.
    public var suggestedReply: String?
    public var jobState: String?
    /// Plan 4 §5.3.1: what the session waits for, from the transcript tail; nil when nothing is open.
    public var pending: PendingInput?

    public init(modelName: String? = nil, effort: String? = nil, contextUsedTokens: Int? = nil, contextWindowSize: Int? = nil,
                contextPercent: Double? = nil, contextIsEstimate: Bool = false, costUSD: Double? = nil,
                lastUserPrompt: String? = nil, lastAssistantText: String? = nil, tasks: [TaskItem] = [],
                branch: String? = nil, lastActivity: Date? = nil, suggestedReply: String? = nil, jobState: String? = nil, pending: PendingInput? = nil) {
        self.modelName = modelName
        self.effort = effort
        self.contextUsedTokens = contextUsedTokens
        self.contextWindowSize = contextWindowSize
        self.contextPercent = contextPercent
        self.contextIsEstimate = contextIsEstimate
        self.costUSD = costUSD
        self.lastUserPrompt = lastUserPrompt
        self.lastAssistantText = lastAssistantText
        self.tasks = tasks
        self.branch = branch
        self.lastActivity = lastActivity
        self.suggestedReply = suggestedReply
        self.jobState = jobState
        self.pending = pending
    }

    public static let empty = SessionDetail()
}
