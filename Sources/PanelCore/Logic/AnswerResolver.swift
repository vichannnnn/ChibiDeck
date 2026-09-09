import Foundation

/// Plan 4 §5.3: the answers one tap may send, from the session's status, the session file's `waitingFor`, the
/// transcript's pending input and the user's quick replies. Pure; the views only draw the result.
public enum AnswerResolver {
    public static let maxAnswers = 4
    /// The `waitingFor` Claude Code writes while a tool permission dialog is up (spec §2, verified 2026-09-08).
    public static let permissionPrompt = "permission prompt"
    /// The `waitingFor` Claude Code writes while an `AskUserQuestion` is up (spec §2).
    public static let inputNeeded = "input needed"
    /// Enter alone: selects the dialog's highlighted `Yes`.
    public static let allow = Answer(label: "Allow ↵", text: "")

    public static func answers(status: SessionStatus, waitingFor: String?, pending: PendingInput?, quickReplies: [String]) -> [Answer] {
        switch status {
        case .waiting:
            if waitingFor == permissionPrompt { return [allow] }              // the session file is authoritative; a stale question cannot outrank it
            if case .question(_, let options) = pending {
                return options.prefix(maxAnswers).enumerated().map { Answer(label: $0.element, text: String($0.offset + 1)) }
            }
            if case .permission = pending, waitingFor != inputNeeded { return [allow] }   // "input needed" with a stale permission: the transcript lags, send nothing
            return []
        case .idle:
            return quickReplies.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.prefix(maxAnswers)
                .map { Answer(label: $0, text: $0) }
        case .busy, .shell, .blocked, .unknown:
            return []
        }
    }

    /// The label of a card's one pill, and whether tapping it sends or opens the sheet.
    public struct CardPill: Sendable, Equatable {
        public let label: String
        public let opensSheet: Bool

        public init(label: String, opensSheet: Bool) {
            self.label = label
            self.opensSheet = opensSheet
        }
    }

    /// The one pill a card shows, labelled from the answers so it can never disagree with what a tap sends: `Allow ↵`
    /// and a quick reply send; only the question's own options (`N opts ›`) open the sheet, where each is a pill.
    public static func cardPill(answers: [Answer], pending: PendingInput?) -> CardPill? {
        guard let first = answers.first else { return nil }
        if first == allow { return CardPill(label: allow.label, opensSheet: false) }
        if case .question = pending, first.text == "1" {                       // the answers are the question's options
            return CardPill(label: "\(answers.count) opts ›", opensSheet: true)
        }
        return CardPill(label: first.label, opensSheet: false)
    }

    /// Plan 4 §9: `go, yes,,no` → `["go", "yes", "no"]`, at most four.
    public static func quickReplies(from setting: String) -> [String] {
        Array(setting.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.prefix(maxAnswers))
    }
}
