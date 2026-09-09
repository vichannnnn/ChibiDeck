import Foundation

public struct DailyActivity: Sendable, Equatable {
    /// `yyyy-MM-dd` as written by Claude Code.
    public let date: String
    public let messageCount: Int
    public let sessionCount: Int
    public let toolCallCount: Int

    public init(date: String, messageCount: Int, sessionCount: Int, toolCallCount: Int) {
        self.date = date
        self.messageCount = messageCount
        self.sessionCount = sessionCount
        self.toolCallCount = toolCallCount
    }
}
