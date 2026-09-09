import Foundation

/// Plan 4 §5.3.1: what a waiting session is waiting for, read from the transcript tail.
public enum PendingInput: Sendable, Equatable {
    /// A tool call waiting for permission: the tool's name and a one-line summary of what it would do.
    case permission(tool: String, summary: String)
    /// An `AskUserQuestion` call: the first question and its option labels, at most four.
    case question(text: String, options: [String])
}

/// Plan 4 §5.3: one thing a tap may send to a session. `text` is typed into the tab; empty means Enter alone.
public struct Answer: Sendable, Equatable {
    public let label: String
    public let text: String

    public init(label: String, text: String) {
        self.label = label
        self.text = text
    }
}
