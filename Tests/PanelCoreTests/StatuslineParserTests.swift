import Foundation
import Testing
@testable import PanelCore

@Suite struct StatuslineParserTests {
    // Field names per Claude Code's statusline documentation; rate_limits mirrors the usage cache shape.
    static let full = """
    {"session_id":"3c4d5e6f-0000-4000-8000-000000000003","transcript_path":"/Users/dev/.claude/projects/-Users-dev-Desktop-demo-app/3c4d5e6f.jsonl",
     "cwd":"/Users/dev/Desktop/demo-app","model":{"id":"claude-fable-5-1[1m]","display_name":"Fable 5.1"},"effort":{"level":"max"},
     "workspace":{"current_dir":"/Users/dev/Desktop/demo-app","project_dir":"/Users/dev/Desktop/demo-app"},
     "version":"2.1.261","cost":{"total_cost_usd":3.92,"total_duration_ms":4509322,"total_lines_added":10,"total_lines_removed":2},
     "context_window":{"total_input_tokens":384456,"total_output_tokens":15002,"context_window_size":1000000,"used_percentage":38.4,"remaining_percentage":61.6},
     "rate_limits":{"five_hour":{"utilization":16,"resets_at":"2026-09-06T04:59:59.831579+00:00"},"seven_day":{"utilization":47,"resets_at":"2026-09-06T05:59:59+00:00"}}}
    """.data(using: .utf8)!

    @Test func parsesEverything() throws {
        let r = try #require(StatuslineParser.parse(Self.full))
        #expect(r.sessionId == "3c4d5e6f-0000-4000-8000-000000000003")
        #expect(r.transcriptPath?.hasSuffix("3c4d5e6f.jsonl") == true)
        #expect(r.modelId == "claude-fable-5-1[1m]")
        #expect(r.modelDisplayName == "Fable 5.1")
        #expect(r.effortLevel == "max")
        #expect(r.contextWindowSize == 1_000_000)
        #expect(r.usedPercentage == 38.4)
        #expect(r.totalInputTokens == 384_456)
        #expect(r.totalCostUSD == 3.92)
        let limits = try #require(r.rateLimits)
        #expect(limits.fiveHour?.utilization == 16)
        #expect(limits.sevenDay?.utilization == 47)
        #expect(limits.fiveHour?.resetsAt == ISO8601.parse("2026-09-06T04:59:59.831579+00:00"))
    }

    @Test func rateLimitsUseTheSuppliedFetchDate() throws {
        let fileDate = Date(timeIntervalSince1970: 1_788_600_000)
        let stamped = try #require(StatuslineParser.parse(Self.full, fetchedAt: fileDate))
        #expect(stamped.rateLimits?.fetchedAt == fileDate)
        let now = Date()
        let defaulted = try #require(StatuslineParser.parse(Self.full))
        let fetched = try #require(defaulted.rateLimits?.fetchedAt)
        #expect(abs(fetched.timeIntervalSince(now)) < 5)          // no date supplied: falls back to now
    }

    // The shape Claude Code documents for the statusline stdin (code.claude.com/docs/en/statusline, 2026-09-07):
    // `used_percentage` 0–100 and `resets_at` as Unix epoch seconds. `spend_limit` is a gateway window the panel ignores.
    static let documented = """
    {"session_id":"s1","rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1738425600},
     "seven_day":{"used_percentage":41.2,"resets_at":1738857600},"spend_limit":{"used_percentage":62.8,"resets_at":1740787200}}}
    """.data(using: .utf8)!

    @Test func parsesTheDocumentedRateLimitShape() throws {
        let r = try #require(StatuslineParser.parse(Self.documented))
        let limits = try #require(r.rateLimits)
        #expect(limits.fiveHour?.utilization == 24)
        #expect(limits.sevenDay?.utilization == 41)
        #expect(limits.fiveHour?.resetsAt == Date(timeIntervalSince1970: 1_738_425_600))
        #expect(limits.sevenDay?.resetsAt == Date(timeIntervalSince1970: 1_738_857_600))
        #expect(limits.rows.map(\.id) == ["session", "weekly"])
    }

    @Test func aWindowMissingFromTheFeedIsSimplyAbsent() throws {
        let data = #"{"session_id":"s","rate_limits":{"seven_day":{"used_percentage":5,"resets_at":1738857600}}}"#.data(using: .utf8)!
        let limits = try #require(StatuslineParser.parse(data)?.rateLimits)
        #expect(limits.fiveHour == nil)
        #expect(limits.sevenDay?.utilization == 5)
    }

    @Test func feedLimitsAreTaggedAsFeed() throws {
        let limits = try #require(StatuslineParser.parse(Self.documented)?.rateLimits)
        #expect(limits.source == .feed)
    }

    @Test func toleratesMissingSections() throws {
        let data = #"{"session_id":"s","model":{"display_name":"Opus 5"}}"#.data(using: .utf8)!
        let r = try #require(StatuslineParser.parse(data))
        #expect(r.modelDisplayName == "Opus 5")
        #expect(r.effortLevel == nil)
        #expect(r.contextWindowSize == nil)
        #expect(r.totalCostUSD == nil)
        #expect(r.rateLimits == nil)
    }

    @Test func missingSessionIdReturnsNil() {
        #expect(StatuslineParser.parse(#"{"model":{"id":"x"}}"#.data(using: .utf8)!) == nil)
    }

    @Test func contextWindowDefaults() {
        #expect(ContextWindow.defaultSize(modelId: "claude-fable-5-1[1m]", displayName: nil) == 1_000_000)
        #expect(ContextWindow.defaultSize(modelId: "claude-opus-5", displayName: "Opus 5 1M") == 1_000_000)
        #expect(ContextWindow.defaultSize(modelId: "claude-opus-5", displayName: "Opus 5") == 200_000)
        #expect(ContextWindow.defaultSize(modelId: nil, displayName: nil) == 200_000)
    }

    @Test func iso8601HandlesFractionalAndWhole() {
        #expect(ISO8601.parse("2026-09-06T04:59:59.831579+00:00") != nil)
        #expect(ISO8601.parse("2026-09-06T05:59:59+00:00") != nil)
        #expect(ISO8601.parse("2026-09-06T05:59:59Z") != nil)
        #expect(ISO8601.parse("not a date") == nil)
    }
}
