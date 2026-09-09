import Foundation
import Testing
@testable import PanelCore

@Suite struct BurnAxisTests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    static func at(_ h: Int, _ m: Int) -> Date { utc.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: h, minute: m))! }
    /// 24 empty bars ending at the hour containing `now`, built the way the panel builds them.
    static func bars(endingAt now: Date) -> [HourBucket] {
        BurnBucketer.chart(from: BurnSummary(buckets: [], indexedAt: now, complete: true, fileCount: 1), now: now, calendar: utc).bars
    }
    static func pairs(_ items: [(index: Int, label: String)]) -> [String] { items.map { "\($0.index):\($0.label)" } }

    @Test func yLabelsAreTopMiddleBottom() {
        #expect(BurnAxis.yLabels(peak: 12_000_000) == ["12M", "6M", "0"])
        #expect(BurnAxis.yLabels(peak: 12_600_000) == ["12.6M", "6.3M", "0"])
        #expect(BurnAxis.yLabels(peak: 640_000) == ["640k", "320k", "0"])
        #expect(BurnAxis.yLabels(peak: 0) == ["0", "", "0"])
    }

    @Test func xLabelsEveryFourHoursAndNow() {
        // Bars run 23:00 (Sep 6) … 22:00 (Sep 7): index i has hour (23 + i) % 24. 20 h is index 21, two before `now`: dropped.
        #expect(Self.pairs(BurnAxis.xLabels(bars: Self.bars(endingAt: Self.at(22, 30)), calendar: Self.utc))
                == ["1:12am", "5:4am", "9:8am", "13:12pm", "17:4pm", "23:now"])
    }

    @Test func nowWinsOverAMultipleOfFour() {
        // Bars 01:00 … 00:00: the last bar is midnight, a multiple of 4, and still reads `now`.
        #expect(Self.pairs(BurnAxis.xLabels(bars: Self.bars(endingAt: Self.at(0, 10)), calendar: Self.utc))
                == ["3:4am", "7:8am", "11:12pm", "15:4pm", "19:8pm", "23:now"])
    }

    @Test func theTwoBarsBeforeNowCarryNoHourLabel() {
        // Bars 03:00 … 02:00: midnight is index 21, two before `now`.
        #expect(Self.pairs(BurnAxis.xLabels(bars: Self.bars(endingAt: Self.at(2, 0)), calendar: Self.utc))
                == ["1:4am", "5:8am", "9:12pm", "13:4pm", "17:8pm", "23:now"])
        // Bars 02:00 … 01:00: midnight is index 22, one before `now`.
        #expect(Self.pairs(BurnAxis.xLabels(bars: Self.bars(endingAt: Self.at(1, 0)), calendar: Self.utc))
                == ["2:4am", "6:8am", "10:12pm", "14:4pm", "18:8pm", "23:now"])
    }

    @Test func emptyAndSingleBar() {
        #expect(BurnAxis.xLabels(bars: [], calendar: Self.utc).isEmpty)
        let one = [HourBucket(hourStart: Self.at(4, 0))]
        #expect(Self.pairs(BurnAxis.xLabels(bars: one, calendar: Self.utc)) == ["0:now"])
    }
}
