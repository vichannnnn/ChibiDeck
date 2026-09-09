import Foundation
import Testing
@testable import PanelCore

@Suite struct LimitForecastTests {
    static let t0 = Date(timeIntervalSince1970: 1_788_728_400)
    static func s(_ minutes: Double, _ percent: Int) -> LimitSample { LimitSample(at: t0.addingTimeInterval(minutes * 60), percent: percent) }
    static let now = t0.addingTimeInterval(11 * 60)
    static let reset = t0.addingTimeInterval(5 * 3600)

    @Test func risingSamplesProjectAFullDate() throws {
        let d = try #require(LimitForecast.fullBy(samples: [Self.s(0, 10), Self.s(5, 15), Self.s(10, 20)], now: Self.now, resetsAt: Self.reset))
        // 10 points in 10 minutes → 80 more points take 80 minutes from the newest sample.
        #expect(abs(d.timeIntervalSince(Self.s(10, 20).at) - 80 * 60) < 1)
    }

    @Test func flatFallingSingleOrShortRunsGiveNil() {
        #expect(LimitForecast.fullBy(samples: [Self.s(0, 20), Self.s(10, 20)], now: Self.now, resetsAt: Self.reset) == nil)
        #expect(LimitForecast.fullBy(samples: [Self.s(0, 30), Self.s(10, 20)], now: Self.now, resetsAt: Self.reset) == nil)
        #expect(LimitForecast.fullBy(samples: [Self.s(10, 20)], now: Self.now, resetsAt: Self.reset) == nil)
        #expect(LimitForecast.fullBy(samples: [Self.s(7, 10), Self.s(10, 20)], now: Self.now, resetsAt: Self.reset) == nil)   // 3 min span
        #expect(LimitForecast.fullBy(samples: [], now: Self.now, resetsAt: Self.reset) == nil)
    }

    @Test func projectionAfterResetIsNil() {
        // 1 point per 10 minutes → 99 points take 16.5 h, well past a 5 h reset.
        #expect(LimitForecast.fullBy(samples: [Self.s(0, 0), Self.s(10, 1)], now: Self.now, resetsAt: Self.reset) == nil)
        #expect(LimitForecast.fullBy(samples: [Self.s(0, 0), Self.s(10, 1)], now: Self.now, resetsAt: nil) != nil)
    }

    @Test func onlyTheRunAfterTheLastDropCounts() throws {
        let samples = [Self.s(-30, 80), Self.s(-20, 90), Self.s(0, 5), Self.s(10, 10)]
        let d = try #require(LimitForecast.fullBy(samples: samples, now: Self.now, resetsAt: Self.now.addingTimeInterval(10 * 3600)))
        #expect(abs(d.timeIntervalSince(Self.s(10, 10).at) - 180 * 60) < 1)   // 5 points per 10 min → 90 points in 180 min
    }

    @Test func samplesOlderThanAnHourAreIgnored() {
        #expect(LimitForecast.fullBy(samples: [Self.s(-70, 0), Self.s(10, 20)], now: Self.now, resetsAt: nil) == nil)
    }

    @Test func storeKeepsOneSamplePerFetchInOrderUpToCapacity() {
        var store = LimitSampleStore()
        func limits(_ minutes: Double, _ percent: Int) -> Limits {
            Limits(rows: [LimitRow(id: "session", title: "5-HOUR", percent: percent, resetsAt: nil)], fetchedAt: Self.t0.addingTimeInterval(minutes * 60))
        }
        store.record(limits(0, 10))
        store.record(limits(0, 11))     // same fetchedAt: ignored
        store.record(limits(-5, 9))     // older: ignored
        store.record(limits(5, 12))
        #expect(store.samples(for: "session").map(\.percent) == [10, 12])
        store.record(Limits(rows: [], fetchedAt: nil))
        #expect(store.samples(for: "session").count == 2)
        for i in 0..<20 { store.record(limits(Double(10 + i), 20 + i)) }
        #expect(store.samples(for: "session").count == LimitSampleStore.capacity)
        #expect(store.samples(for: "session").last?.percent == 39)
        #expect(store.samples(for: "weekly").isEmpty)
    }

    /// Plan 3 §8.5: the statusline feed writes every few seconds. Fifteen minutes of those writes must still leave
    /// a ring that spans long enough for a forecast, so `record` thins them to one sample per minute.
    @Test func fiveSecondFeedWritesAreThinnedToOnePerMinute() throws {
        var store = LimitSampleStore()
        for i in 0..<180 {
            let row = LimitRow(id: "session", title: "5-HOUR", percent: 10 + i / 15, resetsAt: nil)
            store.record(Limits(rows: [row], fetchedAt: Self.t0.addingTimeInterval(Double(i) * 5)))
        }
        let kept = store.samples(for: "session")
        #expect(kept.count == LimitSampleStore.capacity)
        #expect(zip(kept, kept.dropFirst()).allSatisfy { $1.at.timeIntervalSince($0.at) >= LimitSampleStore.minimumSpacing })
        let first = try #require(kept.first), last = try #require(kept.last)
        #expect(last.at.timeIntervalSince(first.at) >= LimitForecast.minimumSpan)
        #expect(LimitForecast.fullBy(samples: kept, now: Self.t0.addingTimeInterval(15 * 60), resetsAt: nil) != nil)
    }

    @Test func forecastsPerRow() {
        var store = LimitSampleStore()
        let rows = { (p: Int, m: Double) in
            Limits(rows: [LimitRow(id: "session", title: "5-HOUR", percent: p, resetsAt: Self.reset),
                          LimitRow(id: "weekly", title: "WEEKLY", percent: 44, resetsAt: nil)], fetchedAt: Self.t0.addingTimeInterval(m * 60))
        }
        store.record(rows(10, 0)); store.record(rows(20, 10))
        let f = LimitForecast.forecasts(limits: rows(20, 10), store: store, now: Self.now)
        #expect(f["session"] != nil)
        #expect(f["weekly"] == nil)
    }
}
