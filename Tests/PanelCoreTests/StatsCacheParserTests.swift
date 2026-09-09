import Foundation
import Testing
@testable import PanelCore

@Suite struct StatsCacheParserTests {
    static let fixture = """
    {"version":4,"lastComputedDate":"2026-09-05","dailyActivity":[
      {"date":"2026-09-01","messageCount":397,"sessionCount":1,"toolCallCount":99},
      {"date":"2026-09-04","messageCount":203,"sessionCount":3,"toolCallCount":63},
      {"date":"2026-09-06","messageCount":1200,"sessionCount":7,"toolCallCount":400}]}
    """.data(using: .utf8)!
    static let utc = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    static func day(_ s: String) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC"); return f.date(from: s)!
    }

    @Test func parsesEntries() {
        let a = StatsCacheParser.parse(Self.fixture)
        #expect(a.count == 3)
        #expect(a[2] == DailyActivity(date: "2026-09-06", messageCount: 1200, sessionCount: 7, toolCallCount: 400))
    }

    @Test func findsTodayOrNil() {
        let a = StatsCacheParser.parse(Self.fixture)
        #expect(StatsCacheParser.entry(for: Self.day("2026-09-06"), in: a, calendar: Self.utc)?.sessionCount == 7)
        #expect(StatsCacheParser.entry(for: Self.day("2026-09-03"), in: a, calendar: Self.utc) == nil)
    }

    @Test func lastSevenDaysFillsGapsWithNil() {
        let a = StatsCacheParser.parse(Self.fixture)
        let week = StatsCacheParser.lastSevenDays(endingOn: Self.day("2026-09-06"), in: a, calendar: Self.utc)
        #expect(week.count == 7)
        #expect(week[0]?.date == "2026-08-31" || week[0] == nil)
        #expect(week[6]?.messageCount == 1200)
        #expect(week[4]?.messageCount == 203)
        #expect(week[5] == nil)
    }

    @Test func garbageGivesEmpty() {
        #expect(StatsCacheParser.parse("x".data(using: .utf8)!).isEmpty)
    }
}
