import Foundation

public struct TranscriptSummary: Sendable, Equatable {
    public var lastUserPrompt: String?
    public var lastAssistantText: String?
    public var modelId: String?
    public var contextTokens: Int?
    public var lastActivity: Date?
    public var pending: PendingInput?
    /// Handoff §4: the last fenced assistant text written after the last `/handoff` command record, and the
    /// timestamp of that assistant record (compared with the request time, so an older handoff never counts).
    public var handoffReply: String?
    public var handoffReplyAt: Date?
    /// Whether a `/handoff` command record was inside the chunk at all: false tells the reader to look further back.
    public var handoffRequested: Bool
    /// Review 2026-09-10: the timestamp of that last `/handoff` record. Typed into a busy session the command is
    /// queued and only runs when the turn ends, so this, not the keystroke, starts the reply clock.
    public var handoffRequestedAt: Date?
    /// Review 2026-09-10: a `turn_duration` system record was written after the reply, i.e. the turn that produced
    /// the block is over. The session file cannot say so: it reports `busy` while any background agent is alive.
    public var handoffTurnEnded: Bool

    public init(lastUserPrompt: String?, lastAssistantText: String?, modelId: String?, contextTokens: Int?, lastActivity: Date?,
                pending: PendingInput? = nil, handoffReply: String? = nil, handoffReplyAt: Date? = nil, handoffRequested: Bool = false,
                handoffRequestedAt: Date? = nil, handoffTurnEnded: Bool = false) {
        self.lastUserPrompt = lastUserPrompt
        self.lastAssistantText = lastAssistantText
        self.modelId = modelId
        self.contextTokens = contextTokens
        self.lastActivity = lastActivity
        self.pending = pending
        self.handoffReply = handoffReply
        self.handoffReplyAt = handoffReplyAt
        self.handoffRequested = handoffRequested
        self.handoffRequestedAt = handoffRequestedAt
        self.handoffTurnEnded = handoffTurnEnded
    }
}

public enum TranscriptTail {
    public static let defaultMaxBytes = 512 * 1024
    /// Handoff §4: what the transcript's `user` record carries when `/handoff` is typed.
    public static let handoffMarker = "<command-name>/handoff</command-name>"
    /// Review 2026-09-10: the `system` record Claude Code writes when a turn ends (seen in 2.1.263 and 2.1.266).
    public static let turnEndSubtype = "turn_duration"

    /// Plan 3 §9.1 step sizes: 4 MiB, then 32 MiB.
    public static let promptSteps = [4 * 1024 * 1024, 32 * 1024 * 1024]

    /// Plan 3 §9.1: reads the last `steps[i]` bytes in turn and returns the first human prompt found, or nil when
    /// no step finds one or the file cannot be read. Each step re-parses its tail; the caller runs this once per
    /// session on a utility thread, so the cost is paid rarely.
    public static func readPrompt(url: URL, steps: [Int] = promptSteps) -> String? {
        for step in steps {
            guard let summary = read(url: url, maxBytes: step) else { return nil }
            if let prompt = summary.lastUserPrompt { return prompt }
        }
        return nil
    }

    public static func encodeProjectDir(_ cwd: String) -> String {
        String(cwd.map { ch in (ch.isLetter || ch.isNumber || ch == "-") ? ch : "-" })
    }

    public static func transcriptURL(cwd: String, sessionId: String, home: URL) -> URL {
        home.appendingPathComponent(".claude/projects/\(encodeProjectDir(cwd))/\(sessionId).jsonl")
    }

    public static func read(url: URL, maxBytes: Int = defaultMaxBytes) -> TranscriptSummary? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        guard (try? handle.seek(toOffset: start)) != nil,
              let data = try? handle.readToEnd() else { return nil }
        let chunk = String(decoding: data, as: UTF8.self)
        return parse(chunk: chunk, dropFirstLine: start > 0)
    }

    public static func parse(chunk: String, dropFirstLine: Bool) -> TranscriptSummary {
        var lines = chunk.split(separator: "\n", omittingEmptySubsequences: true)
        if dropFirstLine, !lines.isEmpty { lines.removeFirst() }

        var summary = TranscriptSummary(lastUserPrompt: nil, lastAssistantText: nil, modelId: nil, contextTokens: nil, lastActivity: nil)
        var open: [(id: String, name: String, input: [String: Any])] = []
        var sawHandoff = false
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }
            if let ts = (o["timestamp"] as? String).flatMap(ISO8601.parse) {
                summary.lastActivity = ts
            }
            let message = o["message"] as? [String: Any]
            switch o["type"] as? String {
            case "user":
                if rawText(message?["content"])?.contains(handoffMarker) == true {   // Handoff §4: a new request voids an older reply
                    sawHandoff = true
                    summary.handoffRequested = true
                    summary.handoffRequestedAt = (o["timestamp"] as? String).flatMap(ISO8601.parse)
                    summary.handoffReply = nil
                    summary.handoffReplyAt = nil
                    summary.handoffTurnEnded = false
                }
                if (o["isMeta"] as? Bool) == true { continue }
                if let text = userText(message?["content"]) {
                    summary.lastUserPrompt = text
                    open.removeAll()                                          // a dialog belongs to the current turn
                }
                for id in toolResultIds(message?["content"]) { open.removeAll { $0.id == id } }
            case "assistant":
                open.append(contentsOf: toolUses(message?["content"]))
                if let text = assistantText(message?["content"]) {
                    summary.lastAssistantText = text
                    // Review 2026-09-08: only a complete fence is a reply — an API-error record ("You've reached your
                    // limit…", `isApiErrorMessage`) or a remark after the block ends the turn too and must not be pasted.
                    if sawHandoff, (o["isApiErrorMessage"] as? Bool) != true, HandoffReply.block(in: text) != nil {
                        summary.handoffReply = text
                        summary.handoffReplyAt = (o["timestamp"] as? String).flatMap(ISO8601.parse)
                        summary.handoffTurnEnded = false
                    }
                }
                if let usage = message?["usage"] as? [String: Any] {
                    let input = (usage["input_tokens"] as? Int) ?? 0
                    let cacheRead = (usage["cache_read_input_tokens"] as? Int) ?? 0
                    let cacheCreate = (usage["cache_creation_input_tokens"] as? Int) ?? 0
                    summary.contextTokens = input + cacheRead + cacheCreate
                    summary.modelId = (message?["model"] as? String) ?? summary.modelId
                }
            case "system":
                if (o["subtype"] as? String) == turnEndSubtype, summary.handoffReply != nil {   // review 2026-09-10
                    summary.handoffTurnEnded = true
                }
            default:
                continue
            }
        }
        summary.pending = open.last.map { pendingInput(name: $0.name, input: $0.input) }
        return summary
    }

    /// The user record's text before the human-prompt filter: a plain string, or the joined `text` blocks.
    static func rawText(_ content: Any?) -> String? {
        if let s = content as? String { return s }
        guard let blocks = content as? [[String: Any]] else { return nil }
        let parts = blocks.compactMap { ($0["type"] as? String) == "text" ? $0["text"] as? String : nil }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// A human prompt: a plain string or the joined `text` blocks, excluding injected content.
    static func userText(_ content: Any?) -> String? {
        let text: String
        if let s = content as? String {
            text = s
        } else if let blocks = content as? [[String: Any]] {
            let parts = blocks.compactMap { b -> String? in
                guard (b["type"] as? String) == "text" else { return nil }
                return b["text"] as? String
            }
            text = parts.joined(separator: " ")
        } else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("<"), !trimmed.hasPrefix("[Image") else { return nil }
        return trimmed
    }

    static func assistantText(_ content: Any?) -> String? {
        guard let blocks = content as? [[String: Any]] else { return nil }
        let parts = blocks.compactMap { b -> String? in
            guard (b["type"] as? String) == "text" else { return nil }
            return b["text"] as? String
        }
        let joined = parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }

    static func toolUses(_ content: Any?) -> [(id: String, name: String, input: [String: Any])] {
        guard let blocks = content as? [[String: Any]] else { return [] }
        return blocks.compactMap { b in
            guard (b["type"] as? String) == "tool_use", let id = b["id"] as? String, let name = b["name"] as? String else { return nil }
            return (id: id, name: name, input: (b["input"] as? [String: Any]) ?? [:])
        }
    }

    static func toolResultIds(_ content: Any?) -> [String] {
        guard let blocks = content as? [[String: Any]] else { return [] }
        return blocks.compactMap { ($0["type"] as? String) == "tool_result" ? $0["tool_use_id"] as? String : nil }
    }

    /// Plan 4 §5.3.1: `AskUserQuestion` becomes a question; any other open tool is a permission wait.
    static func pendingInput(name: String, input: [String: Any]) -> PendingInput {
        if name == "AskUserQuestion" {
            let first = (input["questions"] as? [[String: Any]])?.first
            let options = ((first?["options"] as? [[String: Any]]) ?? []).compactMap { $0["label"] as? String }
            return .question(text: (first?["question"] as? String) ?? "", options: Array(options.prefix(AnswerResolver.maxAnswers)))
        }
        return .permission(tool: name, summary: toolSummary(input))
    }

    /// Bash: the command's first line, whitespace squashed, at most 80 characters. A file tool: the last two path
    /// components. Anything else: its description, or nothing.
    static func toolSummary(_ input: [String: Any]) -> String {
        if let command = input["command"] as? String {
            let firstLine = command.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
            let squashed = firstLine.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
            return squashed.count > 80 ? String(squashed.prefix(79)) + "…" : squashed
        }
        if let path = input["file_path"] as? String {
            return path.split(separator: "/").suffix(2).joined(separator: "/")
        }
        return (input["description"] as? String) ?? ""
    }
}
