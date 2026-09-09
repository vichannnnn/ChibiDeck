import Foundation
import Testing
@testable import PanelCore

@Suite struct TranscriptTailTests {
    static let lines: [String] = [
        // partial first line as produced by seeking into the middle of a file
        #"ent":"garbage that must be dropped"}}"#,
        #"{"type":"user","isMeta":true,"message":{"role":"user","content":"<system-reminder>injected</system-reminder>"},"timestamp":"2026-09-06T00:50:00.000Z"}"#,
        #"{"type":"user","message":{"role":"user","content":"Please prepare the handoff prompt"},"timestamp":"2026-09-06T00:50:10.000Z"}"#,
        #"{"type":"assistant","message":{"model":"claude-opus-5","role":"assistant","content":[{"type":"thinking","thinking":"hmm"},{"type":"text","text":"Here is the handoff prompt."}],"usage":{"input_tokens":32,"cache_creation_input_tokens":2234,"cache_read_input_tokens":400000,"output_tokens":919}},"timestamp":"2026-09-06T00:50:20.209Z"}"#,
        #"{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"ok"}]},"timestamp":"2026-09-06T00:50:21.000Z"}"#,
        #"{"type":"user","message":{"role":"user","content":"<task-notification>done</task-notification>"},"timestamp":"2026-09-06T00:50:22.000Z"}"#,
        #"{"type":"user","message":{"role":"user","content":"[Image: original 1330x2985]"},"timestamp":"2026-09-06T00:50:23.000Z"}"#,
        #"{"type":"assistant","message":{"model":"claude-opus-5","role":"assistant","content":[{"type":"tool_use","id":"t2","name":"Bash","input":{}}],"usage":{"input_tokens":5,"cache_creation_input_tokens":100,"cache_read_input_tokens":410000,"output_tokens":50}},"timestamp":"2026-09-06T00:50:30.000Z"}"#,
        #"{"type":"total_tokens_reminder","timestamp":"2026-09-06T00:50:31.000Z"}"#,
        "not json at all",
    ]
    static var chunk: String { lines.joined(separator: "\n") + "\n" }

    @Test func picksLastRealPromptAndLastAssistantText() {
        let s = TranscriptTail.parse(chunk: Self.chunk, dropFirstLine: true)
        #expect(s.lastUserPrompt == "Please prepare the handoff prompt")
        #expect(s.lastAssistantText == "Here is the handoff prompt.")
    }

    @Test func usageComesFromLastAssistantLineEvenWithoutText() {
        let s = TranscriptTail.parse(chunk: Self.chunk, dropFirstLine: true)
        #expect(s.contextTokens == 5 + 100 + 410_000)
        #expect(s.modelId == "claude-opus-5")
        #expect(s.lastActivity == ISO8601.parse("2026-09-06T00:50:31.000Z"))
    }

    @Test func blockContentPromptsAreJoined() {
        let line = #"{"type":"user","message":{"role":"user","content":[{"type":"text","text":"first"},{"type":"text","text":"second"}]},"timestamp":"2026-09-06T01:00:00Z"}"#
        let s = TranscriptTail.parse(chunk: line + "\n", dropFirstLine: false)
        #expect(s.lastUserPrompt == "first second")
    }

    @Test func emptyChunkGivesEmptySummary() {
        let s = TranscriptTail.parse(chunk: "", dropFirstLine: false)
        #expect(s == TranscriptSummary(lastUserPrompt: nil, lastAssistantText: nil, modelId: nil, contextTokens: nil, lastActivity: nil))
    }

    @Test func encodesProjectDirectory() {
        #expect(TranscriptTail.encodeProjectDir("/Users/dev/Desktop/demo-app") == "-Users-dev-Desktop-demo-app")
        #expect(TranscriptTail.encodeProjectDir("/Users/dev/.claude/session-keeper") == "-Users-dev--claude-session-keeper")
        #expect(TranscriptTail.encodeProjectDir("/Users/dev/Desktop/work/TICKET-1") == "-Users-dev-Desktop-work-TICKET-1")
    }

    @Test func buildsTranscriptURL() {
        let url = TranscriptTail.transcriptURL(cwd: "/Users/dev/Desktop/demo-app", sessionId: "abc", home: URL(fileURLWithPath: "/Users/dev"))
        #expect(url.path == "/Users/dev/.claude/projects/-Users-dev-Desktop-demo-app/abc.jsonl")
    }

    @Test func readsOnlyTheTailOfAFile() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("tail-\(UUID().uuidString).jsonl")
        var text = String(repeating: #"{"type":"user","message":{"role":"user","content":"old old old old old old"},"timestamp":"2026-09-06T00:00:00Z"}"# + "\n", count: 200)
        text += #"{"type":"user","message":{"role":"user","content":"newest"},"timestamp":"2026-09-06T00:00:01Z"}"# + "\n"
        try text.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let s = try #require(TranscriptTail.read(url: tmp, maxBytes: 400))
        #expect(s.lastUserPrompt == "newest")
    }

    @Test func missingFileReturnsNil() {
        #expect(TranscriptTail.read(url: URL(fileURLWithPath: "/nonexistent/x.jsonl")) == nil)
    }

    @Test func readPromptStepsBackUntilAHumanPromptAppears() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("transcript-tail-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("session.jsonl")
        let prompt = #"{"type":"user","message":{"role":"user","content":"deep prompt"},"timestamp":"2026-09-07T01:00:00Z"}"#
        let toolResult = #"{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t","content":""#
            + String(repeating: "x", count: 900) + #""}]},"timestamp":"2026-09-07T01:00:01Z"}"#
        // ≈ 1.1 MB of tool output after the only human prompt: the 512 KB tail never sees it.
        let body = ([prompt] + Array(repeating: toolResult, count: 1200)).joined(separator: "\n") + "\n"
        try body.write(to: url, atomically: true, encoding: .utf8)

        #expect(TranscriptTail.read(url: url)?.lastUserPrompt == nil)
        #expect(TranscriptTail.readPrompt(url: url, steps: [256 * 1024]) == nil)
        #expect(TranscriptTail.readPrompt(url: url, steps: [256 * 1024, 4 * 1024 * 1024]) == "deep prompt")
        #expect(TranscriptTail.readPrompt(url: url) == "deep prompt")
        #expect(TranscriptTail.readPrompt(url: dir.appendingPathComponent("missing.jsonl")) == nil)
    }

    static func record(_ type: String, _ content: String, ts: String = "2026-09-08T00:00:00Z") -> String {
        #"{"type":"\#(type)","message":{"role":"\#(type)","content":\#(content)},"timestamp":"\#(ts)"}"#
    }
    static let bashUse = record("assistant", #"[{"type":"tool_use","id":"tb","name":"Bash","input":{"command":"touch   probe-3 && curl -s https://example.com\nsecond line"}}]"#)
    static let bashResult = record("user", #"[{"type":"tool_result","tool_use_id":"tb","content":"ok"}]"#)
    static let question = record("assistant", #"[{"type":"tool_use","id":"tq","name":"AskUserQuestion","input":{"questions":[{"question":"Pick a colour","header":"Colour","options":[{"label":"Red"},{"label":"Blue"}]}]}}]"#)
    static let prompt = record("user", #""go""#)

    @Test func anOpenToolIsThePendingPermission() {
        let s = TranscriptTail.parse(chunk: [Self.prompt, Self.bashUse].joined(separator: "\n") + "\n", dropFirstLine: false)
        #expect(s.pending == .permission(tool: "Bash", summary: "touch probe-3 && curl -s https://example.com"))
    }

    @Test func aToolResultClearsThePendingInput() {
        let s = TranscriptTail.parse(chunk: [Self.prompt, Self.bashUse, Self.bashResult].joined(separator: "\n") + "\n", dropFirstLine: false)
        #expect(s.pending == nil)
    }

    @Test func askUserQuestionIsAPendingQuestion() {
        let s = TranscriptTail.parse(chunk: [Self.prompt, Self.question].joined(separator: "\n") + "\n", dropFirstLine: false)
        #expect(s.pending == .question(text: "Pick a colour", options: ["Red", "Blue"]))
    }

    @Test func aNewHumanPromptClearsAnOrphanedTool() {
        let s = TranscriptTail.parse(chunk: [Self.bashUse, Self.prompt].joined(separator: "\n") + "\n", dropFirstLine: false)
        #expect(s.pending == nil)
    }

    @Test func theLastOpenToolWinsAndInjectedTextDoesNotReset() {
        let notice = Self.record("user", #""<task-notification>done</task-notification>""#)
        let edit = Self.record("assistant", #"[{"type":"tool_use","id":"te","name":"Edit","input":{"file_path":"/Users/dev/Desktop/x/Sources/App/Main.swift"}}]"#)
        let s = TranscriptTail.parse(chunk: [Self.prompt, Self.bashUse, Self.bashResult, edit, notice].joined(separator: "\n") + "\n", dropFirstLine: false)
        #expect(s.pending == .permission(tool: "Edit", summary: "App/Main.swift"))
    }

    /// Spec §10: two tools open at once. The last one opened is the pending input; each `tool_result` uncovers the one
    /// before it, and the last result leaves nothing pending.
    @Test func twoOpenToolsUncoverEachOtherInTurn() {
        let a = Self.record("assistant", #"[{"type":"tool_use","id":"t-a","name":"Bash","input":{"command":"swift build"}}]"#)
        let b = Self.record("assistant", #"[{"type":"tool_use","id":"t-b","name":"Edit","input":{"file_path":"/Users/dev/Desktop/x/Sources/App/Main.swift"}}]"#)
        let resultB = Self.record("user", #"[{"type":"tool_result","tool_use_id":"t-b","content":"ok"}]"#)
        let resultA = Self.record("user", #"[{"type":"tool_result","tool_use_id":"t-a","content":"ok"}]"#)
        func pending(_ lines: [String]) -> PendingInput? {
            TranscriptTail.parse(chunk: lines.joined(separator: "\n") + "\n", dropFirstLine: false).pending
        }
        #expect(pending([Self.prompt, a, b]) == .permission(tool: "Edit", summary: "App/Main.swift"))
        #expect(pending([Self.prompt, a, b, resultB]) == .permission(tool: "Bash", summary: "swift build"))
        #expect(pending([Self.prompt, a, b, resultB, resultA]) == nil)
    }

    @Test func longCommandsAreCutAndDescribedToolsUseTheirDescription() {
        let long = Self.record("assistant", #"[{"type":"tool_use","id":"tl","name":"Bash","input":{"command":"\#(String(repeating: "x", count: 100))"}}]"#)
        #expect(TranscriptTail.parse(chunk: long + "\n", dropFirstLine: false).pending == .permission(tool: "Bash", summary: String(repeating: "x", count: 79) + "…"))
        let agent = Self.record("assistant", #"[{"type":"tool_use","id":"ta","name":"Agent","input":{"description":"Review Task 7","prompt":"..."}}]"#)
        #expect(TranscriptTail.parse(chunk: agent + "\n", dropFirstLine: false).pending == .permission(tool: "Agent", summary: "Review Task 7"))
        #expect(TranscriptTail.parse(chunk: Self.chunk, dropFirstLine: true).pending == .permission(tool: "Bash", summary: ""))   // the old fixture ends on an open Bash call
    }

    static let handoffLines: [String] = [
        #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"old reply"}]},"timestamp":"2026-09-08T08:00:00Z"}"#,
        #"{"type":"user","message":{"role":"user","content":"<command-message>handoff</command-message>\n<command-name>/handoff</command-name>"},"timestamp":"2026-09-08T08:00:01Z"}"#,
        #"{"type":"user","isMeta":true,"message":{"role":"user","content":"Base directory for this skill: /Users/x/.claude/skills/handoff"},"timestamp":"2026-09-08T08:00:02Z"}"#,
        #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"git status"}}]},"timestamp":"2026-09-08T08:00:03Z"}"#,
        #"{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"clean"}]},"timestamp":"2026-09-08T08:00:04Z"}"#,
        #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Handoff below.\n\n```\nYou are continuing work.\n```"}]},"timestamp":"2026-09-08T08:00:05Z"}"#,
    ]

    @Test func handoffReplyIsTheAssistantTextWrittenAfterTheHandoffCommand() {
        let s = TranscriptTail.parse(chunk: Self.handoffLines.joined(separator: "\n") + "\n", dropFirstLine: false)
        #expect(s.handoffReply == "Handoff below.\n\n```\nYou are continuing work.\n```")
        #expect(s.handoffReplyAt == ISO8601.parse("2026-09-08T08:00:05Z"))
        #expect(s.lastUserPrompt == nil)                                   // the command record is not a human prompt
        #expect(s.pending == nil)
        #expect(s.handoffRequested)
    }

    @Test func handoffReplyIgnoresApiErrorsRemarksAndAnOlderHandoff() {
        let apiError = #"{"type":"assistant","isApiErrorMessage":true,"message":{"role":"assistant","content":[{"type":"text","text":"You've reached your limit. Run /usage-credits to continue."}]},"timestamp":"2026-09-08T08:00:06Z"}"#
        let remark = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Also saved to HANDOFF.md."}]},"timestamp":"2026-09-08T08:00:07Z"}"#
        let errored = TranscriptTail.parse(chunk: Self.handoffLines[0..<5].joined(separator: "\n") + "\n" + apiError + "\n", dropFirstLine: false)
        #expect(errored.handoffReply == nil && errored.handoffRequested)
        let trailing = TranscriptTail.parse(chunk: Self.handoffLines.joined(separator: "\n") + "\n" + remark + "\n", dropFirstLine: false)
        #expect(trailing.handoffReply == "Handoff below.\n\n```\nYou are continuing work.\n```")
        #expect(trailing.handoffReplyAt == ISO8601.parse("2026-09-08T08:00:05Z"))
        #expect(trailing.lastAssistantText == "Also saved to HANDOFF.md.")
        let again = TranscriptTail.parse(chunk: Self.handoffLines.joined(separator: "\n") + "\n" + Self.handoffLines[1] + "\n", dropFirstLine: false)
        #expect(again.handoffReply == nil && again.handoffReplyAt == nil && again.handoffRequested)   // a second request voids the first reply
    }

    @Test func handoffMarkerCountsInTextBlocksButNotInToolResults() {
        let blockForm = #"{"type":"user","message":{"role":"user","content":[{"type":"text","text":"<command-message>handoff</command-message>\n<command-name>/handoff</command-name>"}]},"timestamp":"2026-09-08T08:00:01Z"}"#
        let inResult = #"{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t9","content":"grep hit: <command-name>/handoff</command-name>"}]},"timestamp":"2026-09-08T08:00:01Z"}"#
        let reply = Self.handoffLines[5]
        #expect(TranscriptTail.parse(chunk: blockForm + "\n" + reply + "\n", dropFirstLine: false).handoffReply != nil)
        let viaResult = TranscriptTail.parse(chunk: inResult + "\n" + reply + "\n", dropFirstLine: false)
        #expect(viaResult.handoffReply == nil && !viaResult.handoffRequested)
    }

    @Test func handoffReplyIsNilBeforeTheCommandAndWhileTheSkillStillRuns() {
        let before = TranscriptTail.parse(chunk: Self.handoffLines[0] + "\n", dropFirstLine: false)
        #expect(before.handoffReply == nil && before.lastAssistantText == "old reply")
        let running = TranscriptTail.parse(chunk: Self.handoffLines[0..<5].joined(separator: "\n") + "\n", dropFirstLine: false)
        #expect(running.handoffReply == nil && running.handoffReplyAt == nil)
        #expect(running.lastAssistantText == "old reply")
        #expect(running.pending == nil)                                    // the tool result closed the dialog
    }

    @Test func handoffRequestedAtIsTheCommandRecordsTimestamp() {
        let s = TranscriptTail.parse(chunk: Self.handoffLines.joined(separator: "\n") + "\n", dropFirstLine: false)
        #expect(s.handoffRequestedAt == ISO8601.parse("2026-09-08T08:00:01Z"))
        let before = TranscriptTail.parse(chunk: Self.handoffLines[0] + "\n", dropFirstLine: false)
        #expect(before.handoffRequestedAt == nil)
    }

    /// Review 2026-09-10: the session file says `busy` between turns while background agents run, so the turn end is
    /// read from the transcript: a `turn_duration` system record written after the reply.
    @Test func handoffTurnEndedOnlyWhenATurnDurationRecordFollowsTheReply() {
        let turnEnd = #"{"type":"system","subtype":"turn_duration","durationMs":4000,"messageCount":6,"timestamp":"2026-09-08T08:00:06Z"}"#
        let open = TranscriptTail.parse(chunk: Self.handoffLines.joined(separator: "\n") + "\n", dropFirstLine: false)
        #expect(open.handoffReply != nil && !open.handoffTurnEnded)
        let closed = TranscriptTail.parse(chunk: Self.handoffLines.joined(separator: "\n") + "\n" + turnEnd + "\n", dropFirstLine: false)
        #expect(closed.handoffTurnEnded)
        let earlier = TranscriptTail.parse(chunk: Self.handoffLines[0..<5].joined(separator: "\n") + "\n" + turnEnd + "\n" + Self.handoffLines[5] + "\n", dropFirstLine: false)
        #expect(earlier.handoffReply != nil && !earlier.handoffTurnEnded)   // a turn that ended before the block does not count
        let again = TranscriptTail.parse(chunk: Self.handoffLines.joined(separator: "\n") + "\n" + turnEnd + "\n" + Self.handoffLines[1] + "\n", dropFirstLine: false)
        #expect(!again.handoffTurnEnded && again.handoffRequestedAt == ISO8601.parse("2026-09-08T08:00:01Z"))   // a new request resets it
    }
}
