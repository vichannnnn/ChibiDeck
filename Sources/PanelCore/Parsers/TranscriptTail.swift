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
    /// Spec 2026-09-23 §3.1: the last non-empty `aiTitle` of an `ai-title` record, Claude Code's own session title.
    public var aiTitle: String?
    /// Spec 2026-09-23 §9.1: what the format check counts: in the tail, or for a continued read in the tail it started
    /// from plus what was appended since (at most twice the tail).
    public var humanPrompts: Int
    public var assistantRecords: Int
    public var turnEnds: Int
    public var sawUsage: Bool

    public init(lastUserPrompt: String?, lastAssistantText: String?, modelId: String?, contextTokens: Int?, lastActivity: Date?,
                pending: PendingInput? = nil, handoffReply: String? = nil, handoffReplyAt: Date? = nil, handoffRequested: Bool = false,
                handoffRequestedAt: Date? = nil, handoffTurnEnded: Bool = false, aiTitle: String? = nil, humanPrompts: Int = 0,
                assistantRecords: Int = 0, turnEnds: Int = 0, sawUsage: Bool = false) {
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
        self.aiTitle = aiTitle
        self.humanPrompts = humanPrompts
        self.assistantRecords = assistantRecords
        self.turnEnds = turnEnds
        self.sawUsage = sawUsage
    }
}

/// What a transcript parse knows between two reads: the summary so far, the tool calls still waiting for a result,
/// and whether a `/handoff` command has been seen.
struct TranscriptParseState: Sendable, Equatable {
    var summary = TranscriptSummary(lastUserPrompt: nil, lastAssistantText: nil, modelId: nil, contextTokens: nil, lastActivity: nil)
    var open: [(id: String, input: PendingInput)] = []
    var sawHandoff = false

    static func == (a: Self, b: Self) -> Bool {
        a.summary == b.summary && a.sawHandoff == b.sawHandoff && a.open.map(\.id) == b.open.map(\.id) && a.open.map(\.input) == b.open.map(\.input)
    }
}

/// Where the last read of one transcript stopped (see `TranscriptTail.read(url:continuing:maxBytes:)`).
public struct TranscriptCursor: Sendable, Equatable {
    let fileID: UInt64
    /// The byte after the last complete line parsed.
    var offset: UInt64
    /// Bytes parsed since the last read that started from the tail.
    var sinceTailRead: UInt64
    var state: TranscriptParseState
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

    /// Carries on from `cursor`: parses only the complete lines appended since it, into the summary the cursor kept.
    /// A new file at the path, a shorter one, or `maxBytes` more appended since the last tail read start over from
    /// the last `maxBytes`, so the summary (and its format-check counts, spec 2026-09-23 §9.1) covers at most the
    /// last `2 × maxBytes`. A line still being written (no newline yet) is left for the next read. Nil when the file
    /// cannot be read.
    public static func read(url: URL, continuing cursor: TranscriptCursor?, maxBytes: Int = defaultMaxBytes)
        -> (summary: TranscriptSummary, cursor: TranscriptCursor)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var info = stat()
        guard fstat(handle.fileDescriptor, &info) == 0, let size = try? handle.seekToEnd() else { return nil }
        let fileID = UInt64(info.st_ino)
        if let c = cursor, c.fileID == fileID, size >= c.offset, c.sinceTailRead + (size - c.offset) <= UInt64(maxBytes) {
            guard (try? handle.seek(toOffset: c.offset)) != nil, let data = try? handle.readToEnd() else { return nil }
            guard let end = data.lastIndex(of: 0x0A) else { return (c.state.summary, c) }
            let complete = data[data.startIndex...end]
            var next = c
            fold(String(decoding: complete, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: true), into: &next.state)
            next.offset += UInt64(complete.count)
            next.sinceTailRead += UInt64(complete.count)
            return (next.state.summary, next)
        }
        let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        guard (try? handle.seek(toOffset: start)) != nil, let data = try? handle.readToEnd() else { return nil }
        var from = data.startIndex
        if start > 0 { from = data.firstIndex(of: 0x0A).map { data.index(after: $0) } ?? data.endIndex }   // a cut first line
        var state = TranscriptParseState()
        var through = from
        if let end = data[from...].lastIndex(of: 0x0A) {
            through = data.index(after: end)
            fold(String(decoding: data[from..<through], as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: true), into: &state)
        }
        return (state.summary, TranscriptCursor(fileID: fileID, offset: start + UInt64(through - data.startIndex), sinceTailRead: 0, state: state))
    }

    public static func parse(chunk: String, dropFirstLine: Bool) -> TranscriptSummary {
        var lines = chunk.split(separator: "\n", omittingEmptySubsequences: true)
        if dropFirstLine, !lines.isEmpty { lines.removeFirst() }
        var state = TranscriptParseState()
        fold(lines, into: &state)
        return state.summary
    }

    /// The parse itself, one record after another, so a later read can carry on from where the last one stopped.
    static func fold(_ lines: some Sequence<Substring>, into state: inout TranscriptParseState) {
        var summary = state.summary
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
                    state.sawHandoff = true
                    summary.handoffRequested = true
                    summary.handoffRequestedAt = (o["timestamp"] as? String).flatMap(ISO8601.parse)
                    summary.handoffReply = nil
                    summary.handoffReplyAt = nil
                    summary.handoffTurnEnded = false
                }
                if (o["isMeta"] as? Bool) == true { continue }
                if let text = userText(message?["content"]) {
                    summary.humanPrompts += 1                                 // spec 2026-09-23 §9.1
                    summary.lastUserPrompt = text
                    state.open.removeAll()                                    // a dialog belongs to the current turn
                }
                for id in toolResultIds(message?["content"]) { state.open.removeAll { $0.id == id } }
            case "assistant":
                summary.assistantRecords += 1                                 // spec 2026-09-23 §9.1
                state.open.append(contentsOf: toolUses(message?["content"]).map { (id: $0.id, input: pendingInput(name: $0.name, input: $0.input)) })
                if let text = assistantText(message?["content"]) {
                    summary.lastAssistantText = text
                    // Review 2026-09-08: only a complete fence is a reply — an API-error record ("You've reached your
                    // limit…", `isApiErrorMessage`) or a remark after the block ends the turn too and must not be pasted.
                    if state.sawHandoff, (o["isApiErrorMessage"] as? Bool) != true, HandoffReply.block(in: text) != nil {
                        summary.handoffReply = text
                        summary.handoffReplyAt = (o["timestamp"] as? String).flatMap(ISO8601.parse)
                        summary.handoffTurnEnded = false
                    }
                }
                if let usage = message?["usage"] as? [String: Any] {
                    summary.sawUsage = true                                    // spec 2026-09-23 §9.1
                    let input = (usage["input_tokens"] as? Int) ?? 0
                    let cacheRead = (usage["cache_read_input_tokens"] as? Int) ?? 0
                    let cacheCreate = (usage["cache_creation_input_tokens"] as? Int) ?? 0
                    summary.contextTokens = input + cacheRead + cacheCreate
                    summary.modelId = (message?["model"] as? String) ?? summary.modelId
                }
            case "system":
                guard (o["subtype"] as? String) == turnEndSubtype else { continue }
                summary.turnEnds += 1                                              // spec 2026-09-23 §9.1
                if summary.handoffReply != nil { summary.handoffTurnEnded = true }  // review 2026-09-10
            case "ai-title":                                                        // spec 2026-09-23 §3.1
                let title = PanelFormat.singleLine((o["aiTitle"] as? String) ?? "")
                if !title.isEmpty { summary.aiTitle = title }
            default:
                continue
            }
        }
        summary.pending = state.open.last?.input
        state.summary = summary
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
