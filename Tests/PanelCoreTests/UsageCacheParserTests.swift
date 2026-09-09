import Foundation
import Testing
@testable import PanelCore

@Suite struct UsageCacheParserTests {
    // Trimmed from ~/.claude.json on 2026-09-06.
    static let fixture = """
    {"numStartups":300,"cachedUsageUtilization":{"fetchedAtMs":1788653493945,"accountUuid":"x",
     "utilization":{"five_hour":{"utilization":16,"resets_at":"2026-09-06T04:59:59.831579+00:00","limit_dollars":null},
                    "seven_day":{"utilization":47,"resets_at":"2026-09-06T05:59:59.831599+00:00"},
                    "seven_day_opus":null,"extra_usage":{"is_enabled":false}}},"theme":"dark"}
    """.data(using: .utf8)!

    @Test func parsesBothWindows() throws {
        let l = try #require(UsageCacheParser.parse(Self.fixture))
        #expect(l.fiveHour?.utilization == 16)
        #expect(l.sevenDay?.utilization == 47)
        #expect(l.fetchedAt == Date(timeIntervalSince1970: 1_788_653_493.945))
        #expect(l.fiveHour?.resetsAt == ISO8601.parse("2026-09-06T04:59:59.831579+00:00"))
    }

    @Test func nullBucketsAreIgnored() throws {
        let data = #"{"cachedUsageUtilization":{"fetchedAtMs":1000,"utilization":{"five_hour":null,"seven_day":{"utilization":3,"resets_at":null}}}}"#.data(using: .utf8)!
        let l = try #require(UsageCacheParser.parse(data))
        #expect(l.fiveHour == nil)
        #expect(l.sevenDay?.utilization == 3)
        #expect(l.sevenDay?.resetsAt == nil)
    }

    @Test func missingKeyReturnsNil() {
        #expect(UsageCacheParser.parse(#"{"theme":"dark"}"#.data(using: .utf8)!) == nil)
        #expect(UsageCacheParser.parse("nope".data(using: .utf8)!) == nil)
    }

    @Test func oldnessUsesFetchedAt() {
        let l = Limits(fiveHour: nil, sevenDay: nil, fetchedAt: Date(timeIntervalSince1970: 0))
        #expect(l.isOld(at: Date(timeIntervalSince1970: 31 * 60)))
        #expect(!l.isOld(at: Date(timeIntervalSince1970: 29 * 60)))
        #expect(Limits.empty.isOld(at: Date()))
    }

    // Trimmed from ~/.claude.json on 2026-09-07 06:00 JST: the `limits[]` array Claude Code now writes.
    static let limitsArrayFixture = """
    {"cachedUsageUtilization":{"fetchedAtMs":1788728164455,"accountUuid":"x",
     "utilization":{"five_hour":{"utilization":20,"resets_at":"2026-09-07T01:40:00.267001+00:00"},
                    "seven_day":{"utilization":44,"resets_at":"2026-09-07T08:00:00.267026+00:00"},
                    "seven_day_opus":null},
     "limits":[
       {"kind":"session","group":"session","percent":20,"severity":"normal","resets_at":"2026-09-07T01:40:00.267001+00:00","scope":null,"is_active":false},
       {"kind":"weekly_all","group":"weekly","percent":44,"severity":"normal","resets_at":"2026-09-07T08:00:00.267026+00:00","scope":null,"is_active":false},
       {"kind":"weekly_scoped","group":"weekly","percent":51,"severity":"normal","resets_at":"2026-09-07T08:00:00.267398+00:00","scope":{"model":{"id":null,"display_name":"Fable"},"surface":null},"is_active":true},
       {"kind":"weekly_scoped","group":"weekly","percent":9,"severity":"normal","resets_at":null,"scope":{"model":{"id":null,"display_name":null},"surface":null},"is_active":false},
       {"kind":"mystery","group":"x","percent":99,"resets_at":null}
     ]}}
    """.data(using: .utf8)!

    @Test func limitsArrayBecomesRows() throws {
        let l = try #require(UsageCacheParser.parse(Self.limitsArrayFixture))
        #expect(l.rows.map(\.id) == ["session", "weekly", "weekly:fable"])
        #expect(l.rows.map(\.title) == ["5-HOUR", "WEEKLY", "FABLE WEEKLY"])
        #expect(l.rows.map(\.percent) == [20, 44, 51])
        #expect(l.rows[2].scopeName == "Fable")
        #expect(l.rows[2].resetsAt == ISO8601.parse("2026-09-07T08:00:00.267398+00:00"))
        #expect(l.fetchedAt == Date(timeIntervalSince1970: 1_788_728_164.455))
    }

    // Trimmed from ~/.claude.json on 2026-09-07 21:46 JST, written by `/usage`: `limits[]` now sits inside `utilization`.
    static let nestedLimitsFixture = """
    {"cachedUsageUtilization":{"fetchedAtMs":1788785218650,"accountUuid":"x",
     "utilization":{"five_hour":{"utilization":49,"resets_at":"2026-09-07T14:40:00.472093+00:00"},
                    "seven_day":{"utilization":57,"resets_at":"2026-09-13T06:00:00.472114+00:00"},
                    "limits":[
                      {"kind":"session","percent":49,"resets_at":"2026-09-07T14:40:00.472093+00:00","scope":null},
                      {"kind":"weekly_all","percent":57,"resets_at":"2026-09-13T06:00:00.472114+00:00","scope":null},
                      {"kind":"weekly_scoped","percent":74,"resets_at":"2026-09-13T06:00:00.472347+00:00","scope":{"model":{"id":null,"display_name":"Fable"},"surface":null}}
                    ]}}}
    """.data(using: .utf8)!

    @Test func limitsArrayNestedUnderUtilizationBecomesRows() throws {
        let l = try #require(UsageCacheParser.parse(Self.nestedLimitsFixture))
        #expect(l.rows.map(\.id) == ["session", "weekly", "weekly:fable"])
        #expect(l.rows.map(\.percent) == [49, 57, 74])
        #expect(l.fetchedAt == Date(timeIntervalSince1970: 1_788_785_218.650))
    }

    @Test func cacheLimitsAreTaggedAsCache() throws {
        #expect(try #require(UsageCacheParser.parse(Self.fixture)).source == .cache)
        #expect(try #require(UsageCacheParser.parse(Self.limitsArrayFixture)).source == .cache)
    }

    @Test func legacyAccessorsReadTheRows() throws {
        let l = try #require(UsageCacheParser.parse(Self.limitsArrayFixture))
        #expect(l.fiveHour?.utilization == 20)
        #expect(l.sevenDay?.utilization == 44)
        #expect(l.row("weekly:fable")?.percent == 51)
        #expect(l.row("nope") == nil)
    }

    @Test func legacyFixtureStillYieldsTwoRows() throws {
        let l = try #require(UsageCacheParser.parse(Self.fixture))
        #expect(l.rows.map(\.id) == ["session", "weekly"])
        #expect(l.rows.map(\.percent) == [16, 47])
    }

    @Test func displayRowsOrderAndCap() {
        let rows = [
            LimitRow(id: "weekly:opus", title: "OPUS WEEKLY", percent: 30, resetsAt: nil, scopeName: "Opus"),
            LimitRow(id: "weekly", title: "WEEKLY", percent: 44, resetsAt: nil),
            LimitRow(id: "weekly:fable", title: "FABLE WEEKLY", percent: 51, resetsAt: nil, scopeName: "Fable"),
            LimitRow(id: "weekly:haiku", title: "HAIKU WEEKLY", percent: 2, resetsAt: nil, scopeName: "Haiku"),
            LimitRow(id: "session", title: "5-HOUR", percent: 20, resetsAt: nil),
        ]
        let l = Limits(rows: rows, fetchedAt: nil)
        #expect(l.displayRows().map(\.id) == ["session", "weekly", "weekly:fable", "weekly:opus"])
        #expect(l.displayRows(max: 2).map(\.id) == ["session", "weekly"])
        #expect(Limits.empty.displayRows().isEmpty)
    }

    @Test func percentIsClamped() {
        #expect(LimitRow(id: "session", title: "5-HOUR", percent: 140, resetsAt: nil).percent == 100)
        #expect(LimitRow(id: "session", title: "5-HOUR", percent: -3, resetsAt: nil).percent == 0)
    }
}
