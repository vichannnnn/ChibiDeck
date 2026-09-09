import Foundation

/// The parts of `~/.claude/jobs/<id>/state.json` the panel shows (spec 2026-09-07 §3.1). All optional: the
/// file is written by Claude Code's background-agent daemon and its shape is not ours.
public struct JobInfo: Sendable, Equatable {
    public let state: String?
    public let detail: String?
    public let needs: String?
    public let suggestedReply: String?
    public let intent: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(state: String? = nil, detail: String? = nil, needs: String? = nil, suggestedReply: String? = nil,
                intent: String? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.state = state
        self.detail = detail
        self.needs = needs
        self.suggestedReply = suggestedReply
        self.intent = intent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
