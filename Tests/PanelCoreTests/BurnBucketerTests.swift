import Foundation
import Testing
@testable import PanelCore

@Suite struct BurnBucketerTests {
    static let utc: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    static func at(_ s: String) -> Date { ISO8601.parse(s)! }

    /// One transcript line the way Claude Code writes it: assistant lines repeat per content block with the same message id.
    static func line(id: String = "msg_1", ts: String = "2026-09-07T05:10:00.000Z", type: String = "assistant",
                     input: Int = 30, cw: Int = 2_000, cr: Int = 100_000, out: Int = 500, withId: Bool = true, withUsage: Bool = true) -> String {
        let idPart = withId ? #""id":"\#(id)","# : ""
        let usage = withUsage ? #","usage":{"input_tokens":\#(input),"cache_creation_input_tokens":\#(cw),"cache_read_input_tokens":\#(cr),"output_tokens":\#(out)}"# : ""
        return #"{"type":"\#(type)","timestamp":"\#(ts)","message":{\#(idPart)"model":"claude-fable-5-1","role":"assistant","content":[{"type":"text","text":"x"}]\#(usage)}}"#
    }

    @Test func parsesAnAssistantUsageLine() throws {
        let r = try #require(BurnBucketer.record(fromLine: Substring(Self.line())))
        #expect(r.messageId == "msg_1")
        #expect(r.timestamp == Self.at("2026-09-07T05:10:00.000Z"))
        #expect(r.input == 30 && r.cacheWrite == 2_000 && r.cacheRead == 100_000 && r.output == 500)
        #expect(r.burn == 2_530)
    }

    @Test func ignoresLinesThatAreNotAssistantUsage() {
        #expect(BurnBucketer.record(fromLine: Substring(Self.line(type: "user"))) == nil)
        #expect(BurnBucketer.record(fromLine: Substring(Self.line(withUsage: false))) == nil)
        #expect(BurnBucketer.record(fromLine: Substring(Self.line(withId: false))) == nil)
        #expect(BurnBucketer.record(fromLine: Substring(#"{"type":"assistant","message":{"id":"m","usage":{"output_tokens":1}}}"#)) == nil)   // no timestamp
        #expect(BurnBucketer.record(fromLine: "not json") == nil)
    }

    @Test func ingestCountsEachMessageIdOnceAndKeepsThePartialTail() {
        let cutoff = Self.at("2026-09-06T00:00:00Z")
        var index = FileBurnIndex()
        let full = Self.line(id: "a") + "\n" + Self.line(id: "a") + "\n" + Self.line(id: "a", out: 999) + "\n"
        let partial = String(Self.line(id: "b").prefix(40))
        let consumed = BurnBucketer.ingest((full + partial).data(using: .utf8)!, into: &index, keepAfter: cutoff)
        #expect(consumed == full.utf8.count)
        #expect(index.bytesScanned == full.utf8.count)
        #expect(index.records.count == 1)
        #expect(index.records["a"]?.output == 999)      // the last line for an id wins
        let rest = String(Self.line(id: "b").dropFirst(40)) + "\n"
        BurnBucketer.ingest(rest.data(using: .utf8)!, into: &index, keepAfter: cutoff)
        #expect(index.records.count == 1)               // the tail alone is not a whole line: nothing new
        #expect(index.bytesScanned == full.utf8.count + rest.utf8.count)
    }

    @Test func ingestReturnsZeroWithoutANewline() {
        var index = FileBurnIndex()
        #expect(BurnBucketer.ingest("no newline".data(using: .utf8)!, into: &index, keepAfter: .distantPast) == 0)
        #expect(index.bytesScanned == 0)
    }

    @Test func cutoffDropsOldRecordsOnIngestAndPrune() {
        var index = FileBurnIndex()
        let text = Self.line(id: "old", ts: "2026-09-01T00:00:00Z") + "\n" + Self.line(id: "new", ts: "2026-09-07T05:00:00Z") + "\n"
        BurnBucketer.ingest(text.data(using: .utf8)!, into: &index, keepAfter: Self.at("2026-09-05T05:00:00Z"))
        #expect(index.records.keys.sorted() == ["new"])
        BurnBucketer.prune(&index, keepAfter: Self.at("2026-09-07T06:00:00Z"))
        #expect(index.records.isEmpty)
    }

    @Test func bucketsByLocalHourWithMidnightBoundary() {
        let records = [
            UsageRecord(messageId: "1", timestamp: Self.at("2026-09-06T23:59:59Z"), input: 1, cacheWrite: 10, cacheRead: 100, output: 1_000),
            UsageRecord(messageId: "2", timestamp: Self.at("2026-09-07T00:00:00Z"), input: 2, cacheWrite: 20, cacheRead: 200, output: 2_000),
            UsageRecord(messageId: "3", timestamp: Self.at("2026-09-07T00:30:00Z"), input: 3, cacheWrite: 30, cacheRead: 300, output: 3_000),
            UsageRecord(messageId: "4", timestamp: Self.at("2026-09-01T00:30:00Z"), input: 9, cacheWrite: 9, cacheRead: 9, output: 9),   // outside the window
        ]
        let b = BurnBucketer.buckets(records: records, count: 3, endingAt: Self.at("2026-09-07T01:15:00Z"), calendar: Self.utc)
        #expect(b.map(\.hourStart) == [Self.at("2026-09-06T23:00:00Z"), Self.at("2026-09-07T00:00:00Z"), Self.at("2026-09-07T01:00:00Z")])
        #expect(b[0].burn == 1_011 && b[0].messages == 1)
        #expect(b[1].burn == 5_055 && b[1].messages == 2 && b[1].output == 5_000 && b[1].input == 5 && b[1].cacheRead == 500)
        #expect(b[2].isEmpty)
    }

    @Test func chartTakesTheLastTwentyFourHoursAndComputesPeakAndMean() {
        let hours = (0..<30).map { Self.at("2026-09-06T00:00:00Z").addingTimeInterval(Double($0) * 3600) }
        let buckets = hours.enumerated().map { i, h in HourBucket(hourStart: h, burn: i * 100, output: i, messages: 1) }
        let summary = BurnSummary(buckets: buckets, indexedAt: hours[29], complete: true, fileCount: 3)
        let chart = BurnBucketer.chart(from: summary, now: Self.at("2026-09-07T05:20:00Z"), calendar: Self.utc)
        #expect(chart.bars.count == 24)
        #expect(chart.bars.first?.hourStart == Self.at("2026-09-06T06:00:00Z"))
        #expect(chart.bars.last?.hourStart == Self.at("2026-09-07T05:00:00Z"))
        #expect(chart.peak == 2_900)
        #expect(abs(chart.mean - Double((6...29).map { $0 * 100 }.reduce(0, +)) / 24) < 0.001)
        let later = BurnBucketer.chart(from: summary, now: Self.at("2026-09-07T09:00:00Z"), calendar: Self.utc)
        #expect(later.bars.last?.isEmpty == true)     // an hour the index has not seen yet is empty, not missing
        #expect(later.bars.count == 24)
    }

    @Test func todaySumsFromLocalMidnight() {
        let buckets = [
            HourBucket(hourStart: Self.at("2026-09-06T23:00:00Z"), burn: 1, output: 10, input: 1, cacheRead: 100, messages: 1),
            HourBucket(hourStart: Self.at("2026-09-07T00:00:00Z"), burn: 2, output: 20, input: 2, cacheRead: 200, messages: 2),
            HourBucket(hourStart: Self.at("2026-09-07T04:00:00Z"), burn: 3, output: 30, input: 3, cacheRead: 300, messages: 3),
            HourBucket(hourStart: Self.at("2026-09-07T07:00:00Z"), burn: 4, output: 40, input: 4, cacheRead: 400, messages: 4),   // future hour, ignored
        ]
        let summary = BurnSummary(buckets: buckets, indexedAt: nil, complete: true, fileCount: 1)
        let t = BurnBucketer.today(from: summary, now: Self.at("2026-09-07T05:20:00Z"), calendar: Self.utc)
        #expect(t == TodayTotals(output: 50, input: 5, cacheRead: 500, messages: 5))
    }

    @Test func fileIndexRoundTripsThroughJSON() throws {
        var index = FileBurnIndex()
        BurnBucketer.ingest((Self.line(id: "a") + "\n").data(using: .utf8)!, into: &index, keepAfter: .distantPast)
        let data = try JSONEncoder().encode(index)
        let back = try JSONDecoder().decode(FileBurnIndex.self, from: data)
        #expect(back == index)
    }
}
