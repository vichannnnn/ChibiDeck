import Foundation
import Testing
@testable import PanelCore

/// Reading a transcript from where the last read stopped: only the appended lines are parsed, and the summary is the
/// one a full parse of the same lines gives.
@Suite struct TranscriptCursorTests {
    static func record(_ type: String, _ content: String, ts: String = "2026-09-24T00:00:00Z") -> String {
        #"{"type":"\#(type)","message":{"role":"\#(type)","content":\#(content)},"timestamp":"\#(ts)"}"#
    }
    static let first = [
        record("user", #""one""#),
        #"{"type":"assistant","message":{"model":"claude-opus-5-5","role":"assistant","content":[{"type":"text","text":"hi"},{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"ls"}}],"usage":{"input_tokens":3,"cache_read_input_tokens":10,"cache_creation_input_tokens":2}},"timestamp":"2026-09-24T00:00:01Z"}"#,
    ]
    static let second = [
        record("user", #"[{"type":"tool_result","tool_use_id":"t1","content":"ok"}]"#, ts: "2026-09-24T00:00:02Z"),
        #"{"type":"assistant","message":{"model":"claude-opus-5-5","role":"assistant","content":[{"type":"text","text":"done"}],"usage":{"input_tokens":4,"cache_read_input_tokens":20,"cache_creation_input_tokens":0}},"timestamp":"2026-09-24T00:00:03Z"}"#,
        #"{"type":"system","subtype":"turn_duration","durationMs":900,"timestamp":"2026-09-24T00:00:04Z"}"#,
        #"{"type":"ai-title","aiTitle":"List the files","sessionId":"s"}"#,
    ]

    static func lines(_ l: [String]) -> String { l.joined(separator: "\n") + "\n" }

    static func tempFile(_ text: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cursor-\(UUID().uuidString).jsonl")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func append(_ text: String, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(text.utf8))
    }

    @Test func appendedLinesGiveTheSameSummaryAsAFullParse() throws {
        let url = try Self.tempFile(Self.lines(Self.first))
        defer { try? FileManager.default.removeItem(at: url) }
        let r1 = try #require(TranscriptTail.read(url: url, continuing: nil))
        #expect(r1.summary == TranscriptTail.parse(chunk: Self.lines(Self.first), dropFirstLine: false))
        #expect(r1.summary.pending == .permission(tool: "Bash", summary: "ls"))

        try Self.append(Self.lines(Self.second), to: url)
        let r2 = try #require(TranscriptTail.read(url: url, continuing: r1.cursor))
        #expect(r2.summary == TranscriptTail.parse(chunk: Self.lines(Self.first + Self.second), dropFirstLine: false))
        #expect(r2.summary.pending == nil && r2.summary.assistantRecords == 2 && r2.summary.turnEnds == 1)
    }

    @Test func onlyTheAppendedBytesAreParsed() throws {
        let url = try Self.tempFile(Self.lines(Self.first))
        defer { try? FileManager.default.removeItem(at: url) }
        let r1 = try #require(TranscriptTail.read(url: url, continuing: nil))
        // Rewrite the first prompt in place (same length, same file): a reader that starts over would see "two".
        let handle = try FileHandle(forUpdating: url)
        let text = Self.lines(Self.first).replacingOccurrences(of: #""one""#, with: #""two""#)
        try handle.write(contentsOf: Data(text.utf8))
        try handle.close()
        try Self.append(Self.lines(Self.second), to: url)
        let r2 = try #require(TranscriptTail.read(url: url, continuing: r1.cursor))
        #expect(r2.summary.lastUserPrompt == "one")
        #expect(r2.summary.lastAssistantText == "done")
    }

    @Test func aHalfWrittenLineWaitsForItsNewline() throws {
        let url = try Self.tempFile(Self.lines(Self.first))
        defer { try? FileManager.default.removeItem(at: url) }
        let r1 = try #require(TranscriptTail.read(url: url, continuing: nil))
        try Self.append(Self.second[1], to: url)                                  // no newline yet
        let r2 = try #require(TranscriptTail.read(url: url, continuing: r1.cursor))
        #expect(r2.summary == r1.summary)
        try Self.append("\n", to: url)
        let r3 = try #require(TranscriptTail.read(url: url, continuing: r2.cursor))
        #expect(r3.summary.assistantRecords == 2)                                 // counted once
        #expect(r3.summary.lastAssistantText == "done")
    }

    @Test func aShorterOrReplacedFileIsReadAgainFromItsTail() throws {
        let url = try Self.tempFile(Self.lines(Self.first + Self.second))
        defer { try? FileManager.default.removeItem(at: url) }
        let r1 = try #require(TranscriptTail.read(url: url, continuing: nil))

        let shorter = Self.lines([Self.record("user", #""fresh""#)])
        let handle = try FileHandle(forUpdating: url)
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data(shorter.utf8))
        try handle.close()
        let r2 = try #require(TranscriptTail.read(url: url, continuing: r1.cursor))
        #expect(r2.summary == TranscriptTail.parse(chunk: shorter, dropFirstLine: false))

        // A new file at the same path (written atomically: another inode), longer than the old one.
        let replaced = Self.lines(Self.second + Self.second + [Self.record("user", #""replaced""#)])
        try replaced.write(to: url, atomically: true, encoding: .utf8)
        let r3 = try #require(TranscriptTail.read(url: url, continuing: r2.cursor))
        #expect(r3.summary == TranscriptTail.parse(chunk: replaced, dropFirstLine: false))
    }

    @Test func theStateStartsOverFromTheTailOnceMaxBytesMoreHaveBeenAppended() throws {
        let url = try Self.tempFile(Self.lines(Self.first))
        defer { try? FileManager.default.removeItem(at: url) }
        let r1 = try #require(TranscriptTail.read(url: url, continuing: nil, maxBytes: 600))
        #expect(r1.summary.humanPrompts == 1)
        let filler = Self.lines(Array(repeating: Self.record("assistant", #"[{"type":"text","text":"more"}]"#), count: 8))
        try Self.append(filler, to: url)                                          // > 600 bytes appended
        let r2 = try #require(TranscriptTail.read(url: url, continuing: r1.cursor, maxBytes: 600))
        #expect(r2.summary == TranscriptTail.read(url: url, maxBytes: 600))       // the tail alone, as a first read
        #expect(r2.summary.humanPrompts == 0)
    }

    @Test func aMissingFileGivesNil() {
        #expect(TranscriptTail.read(url: URL(fileURLWithPath: "/nonexistent/x.jsonl"), continuing: nil) == nil)
    }
}
