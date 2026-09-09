import Foundation
import Testing
@testable import PanelCore

@Suite struct FormattersTests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    static func at(_ h: Int, _ m: Int, day: Int = 6) -> Date { utc.date(from: DateComponents(year: 2026, month: 9, day: day, hour: h, minute: m))! }

    @Test func elapsedBuckets() {
        #expect(PanelFormat.elapsed(48 * 60) == "0h 48m")
        #expect(PanelFormat.elapsed(2 * 3600 + 41 * 60) == "2h 41m")
        #expect(PanelFormat.elapsed(2 * 86400 + 3 * 3600 + 500) == "2d 3h")
        #expect(PanelFormat.elapsed(-5) == "0h 0m")
    }

    @Test func clockAndReset() {
        #expect(PanelFormat.hhmm(Self.at(9, 58), calendar: Self.utc) == "09:58")
        #expect(PanelFormat.reset(Self.at(13, 59), now: Self.at(9, 58), calendar: Self.utc) == "13:59")
        #expect(PanelFormat.reset(Self.at(15, 0, day: 8), now: Self.at(9, 58), calendar: Self.utc) == "Tue 15:00")
        #expect(PanelFormat.reset(nil, now: Self.at(9, 58), calendar: Self.utc) == "—")
    }

    @Test func modelAndPath() {
        #expect(PanelFormat.shortModel("Fable 5.1") == "Fable")
        #expect(PanelFormat.shortModel("claude-opus-5") == "Opus")
        #expect(PanelFormat.shortModel("claude-fable-5-1[1m]") == "Fable")
        #expect(PanelFormat.shortModel(nil) == "?")
        #expect(PanelFormat.homeRelative("/Users/dev/Desktop/demo-app", home: "/Users/dev") == "~/Desktop/demo-app")
        #expect(PanelFormat.homeRelative("/tmp/x", home: "/Users/dev") == "/tmp/x")
    }

    @Test func costFormatting() {
        #expect(PanelFormat.cost(14.3) == "$14.30")
        #expect(PanelFormat.cost(nil) == "—")
    }

    @Test func compactTokens() {
        #expect(PanelFormat.compactTokens(642) == "642")
        #expect(PanelFormat.compactTokens(1_600) == "1.6k")
        #expect(PanelFormat.compactTokens(4_000) == "4k")
        #expect(PanelFormat.compactTokens(155_492) == "155k")
        #expect(PanelFormat.compactTokens(1_000_000) == "1M")
        #expect(PanelFormat.compactTokens(19_600_000) == "19.6M")
        #expect(PanelFormat.compactTokens(168_900_000) == "168M")           // from 100M the decimal is dropped: five characters at most
        #expect(PanelFormat.compactTokens(99_950_000) == "100M")            // the M tier's own rounding reaches the same width
        #expect(PanelFormat.compactTokens(1_067_700_000) == "1.1B")
        #expect(PanelFormat.compactTokens(1_000_000_000) == "1B")
    }

    @Test func resetsInCountsDownToTheSecond() {
        let now = Self.at(5, 20)
        #expect(PanelFormat.resetsIn(Self.at(6, 58).addingTimeInterval(22), now: now, calendar: Self.utc) == "resets in 1:38:22")
        #expect(PanelFormat.resetsIn(Self.at(10, 0), now: now, calendar: Self.utc) == "resets in 4:40:00")
        #expect(PanelFormat.resetsIn(Self.at(5, 24).addingTimeInterval(9), now: now, calendar: Self.utc) == "resets in 0:04:09")
        #expect(PanelFormat.resetsIn(Self.at(5, 0), now: now, calendar: Self.utc) == "resets in 0:00:00")       // past due
        #expect(PanelFormat.resetsIn(Self.at(17, 0, day: 8), now: now, calendar: Self.utc) == "resets Tue 17:00")
        #expect(PanelFormat.resetsIn(nil, now: now, calendar: Self.utc) == "resets —")
    }

    @Test func fullByIsUnchanged() {
        let now = Self.at(5, 20)
        #expect(PanelFormat.fullBy(Self.at(9, 10), now: now, calendar: Self.utc) == "~full by 09:10")
        #expect(PanelFormat.fullBy(Self.at(9, 10, day: 8), now: now, calendar: Self.utc) == "~full Tue 09:10")
        #expect(PanelFormat.fullBy(nil, now: now, calendar: Self.utc) == nil)
    }

    @Test func elapsedShortBuckets() {
        #expect(PanelFormat.elapsedShort(14 * 60) == "14m")
        #expect(PanelFormat.elapsedShort(72 * 60) == "1h 12m")
        #expect(PanelFormat.elapsedShort(2 * 86400 + 3 * 3600) == "2d 3h")
        #expect(PanelFormat.elapsedShort(56 * 86400 + 7 * 3600) == "56d")
        #expect(PanelFormat.elapsedShort(-1) == "0m")
    }

    @Test func modelLabelHasFamilyAndVersion() {
        #expect(PanelFormat.modelLabel("Fable 5.1") == "Fable 5.1")
        #expect(PanelFormat.modelLabel("claude-fable-5-1[1m]") == "Fable 5.1")
        #expect(PanelFormat.modelLabel("claude-fable-5-1") == "Fable 5.1")
        #expect(PanelFormat.modelLabel("claude-opus-5") == "Opus 5")
        #expect(PanelFormat.modelLabel("claude-haiku-4-5-20251001") == "Haiku 4.5")
        #expect(PanelFormat.modelLabel("Sonnet 5") == "Sonnet 5")
        #expect(PanelFormat.modelLabel("Opus 5 1M") == "Opus 5")
        #expect(PanelFormat.modelLabel("Fable") == "Fable")
        #expect(PanelFormat.modelLabel("Zephyr 2") == "Zephyr 2")
        #expect(PanelFormat.modelLabel(nil) == "?")
        #expect(PanelFormat.modelLabel("") == "?")
    }

    @Test func contextLabelIsPlain() {
        #expect(PanelFormat.contextLabel(used: 375_000, size: 1_000_000) == "375k / 1M")
        #expect(PanelFormat.contextLabel(used: 87_000, size: 200_000) == "87k / 200k")
        #expect(PanelFormat.contextLabel(used: nil, size: 1_000_000) == "—")
        #expect(PanelFormat.contextLabel(used: 10, size: 0) == "—")
    }

    @Test func hourLabelIsTwelveHour() {
        #expect(PanelFormat.hourLabel(Self.at(0, 0), calendar: Self.utc) == "12am")
        #expect(PanelFormat.hourLabel(Self.at(4, 30), calendar: Self.utc) == "4am")
        #expect(PanelFormat.hourLabel(Self.at(12, 0), calendar: Self.utc) == "12pm")
        #expect(PanelFormat.hourLabel(Self.at(16, 0), calendar: Self.utc) == "4pm")
        #expect(PanelFormat.hourLabel(Self.at(23, 59), calendar: Self.utc) == "11pm")
    }
}
