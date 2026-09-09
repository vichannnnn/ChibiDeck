import Foundation
import Testing
@testable import PanelCore

@Suite struct LimitsMergeTests {
    static func t(_ s: TimeInterval) -> Date { Date(timeIntervalSince1970: s) }

    /// The cache shape seen at 05:56 on 2026-09-07: three rows including the Fable weekly limit.
    static let cache = Limits(rows: [
        LimitRow(id: "session", title: "5-HOUR", percent: 20, resetsAt: nil),
        LimitRow(id: "weekly", title: "WEEKLY", percent: 44, resetsAt: nil),
        LimitRow(id: "weekly:fable", title: "FABLE WEEKLY", percent: 51, resetsAt: nil, scopeName: "Fable"),
    ], fetchedAt: t(1000))

    /// A statusline feed file: only the two account-wide rows, newer than the cache.
    static let feed = Limits(fiveHour: LimitWindow(utilization: 25, resetsAt: nil),
                             sevenDay: LimitWindow(utilization: 45, resetsAt: nil), fetchedAt: t(2000))

    @Test func newerFeedOverwritesSharedRowsAndKeepsTheScopedRow() {
        let m = Self.cache.merging(Self.feed)
        #expect(m.rows.map(\.id) == ["session", "weekly", "weekly:fable"])
        #expect(m.row("session")?.percent == 25)
        #expect(m.row("weekly")?.percent == 45)
        #expect(m.row("weekly:fable")?.percent == 51)
        #expect(m.row("session")?.fetchedAt == Self.t(2000))
        #expect(m.row("weekly:fable")?.fetchedAt == Self.t(1000))
        #expect(m.fetchedAt == Self.t(2000))
    }

    @Test func olderSourceDoesNotOverwrite() {
        let old = Limits(fiveHour: LimitWindow(utilization: 5, resetsAt: nil), sevenDay: nil, fetchedAt: Self.t(500))
        let m = Self.cache.merging(old)
        #expect(m.row("session")?.percent == 20)
        #expect(m.row("session")?.fetchedAt == Self.t(1000))
        #expect(m.fetchedAt == Self.t(1000))
        #expect(m.rows.count == 3)
    }

    @Test func mergingTheSameCacheTwiceChangesNothing() {
        let once = Self.cache.merging(Self.cache)
        #expect(once.merging(Self.cache) == once)
        #expect(once.rows.map(\.percent) == [20, 44, 51])
        #expect(once.rows.allSatisfy { $0.fetchedAt == Self.t(1000) })
    }

    @Test func emptyMergesEitherWay() {
        #expect(Limits.empty.merging(Self.cache).rows.count == 3)
        #expect(Self.cache.merging(.empty).rows.count == 3)
        #expect(Self.cache.merging(.empty).fetchedAt == Self.t(1000))
        #expect(Limits.empty.merging(.empty) == .empty)
    }

    @Test func mergeKeepsTheNewerSetsSource() {
        let cache = Limits(rows: Self.cache.rows, fetchedAt: Self.t(1000), source: .cache)
        let feed = Limits(rows: Self.feed.rows, fetchedAt: Self.t(2000), source: .feed)
        #expect(cache.merging(feed).source == .feed)
        #expect(feed.merging(cache).source == .feed)
        #expect(cache.merging(.empty).source == .cache)
        #expect(Limits.empty.source == nil)
    }

    @Test func mergeTiesGoToTheOtherSetsSource() {
        let a = Limits(rows: Self.cache.rows, fetchedAt: Self.t(1000), source: .cache)
        let b = Limits(rows: Self.feed.rows, fetchedAt: Self.t(1000), source: .feed)
        #expect(a.merging(b).source == .feed)
    }

    @Test func rowsWithoutAnyFetchDateStillMerge() {
        let undated = Limits(rows: [LimitRow(id: "session", title: "5-HOUR", percent: 9, resetsAt: nil)], fetchedAt: nil)
        let m = undated.merging(Self.cache)
        #expect(m.row("session")?.percent == 20)          // a dated row beats an undated one
        #expect(Self.cache.merging(undated).row("session")?.percent == 20)
    }

    @Test func staleScopedRowsLeaveTheDisplay() {
        let m = Self.cache.merging(Self.feed)
        #expect(m.displayRows(now: Self.t(1000 + 5 * 3600)).map(\.id) == ["session", "weekly", "weekly:fable"])
        #expect(m.displayRows(now: Self.t(1000 + 7 * 3600)).map(\.id) == ["session", "weekly"])
        #expect(m.displayRows().count == 3)                                  // no `now`: no age filter (Plan 2 callers)
        #expect(Self.cache.displayRows(now: Self.t(1000 + 7 * 3600)).count == 3)   // unstamped rows are never aged
    }

    @Test func samplesUseEachRowsOwnFetchDate() {
        var store = LimitSampleStore()
        store.record(Self.cache.merging(Self.feed))
        #expect(store.samples(for: "weekly:fable").map(\.at) == [Self.t(1000)])
        #expect(store.samples(for: "session").map(\.at) == [Self.t(2000)])
        store.record(Self.cache.merging(Self.feed))                          // same data again: no new samples
        #expect(store.samples(for: "session").count == 1)
    }

    @Test func newerScopedRowReplacesTheOlderOne() {
        let older = Limits(rows: [LimitRow(id: "weekly:fable", title: "FABLE WEEKLY", percent: 51, resetsAt: nil, scopeName: "Fable")], fetchedAt: Self.t(1000))
        let newer = Limits(rows: [LimitRow(id: "weekly:fable", title: "FABLE WEEKLY", percent: 74, resetsAt: nil, scopeName: "Fable")], fetchedAt: Self.t(2000))
        #expect(older.merging(newer).row("weekly:fable")?.percent == 74)
        #expect(newer.merging(older).row("weekly:fable")?.percent == 74)
        #expect(newer.merging(older).row("weekly:fable")?.fetchedAt == Self.t(2000))
    }

    @Test func duplicateIdsInsideOneSetResolveToTheLaterEntry() {
        let dup = Limits(rows: [LimitRow(id: "session", title: "5-HOUR", percent: 10, resetsAt: nil),
                                LimitRow(id: "session", title: "5-HOUR", percent: 12, resetsAt: nil)], fetchedAt: Self.t(1000))
        let m = Limits.empty.merging(dup)
        #expect(m.rows.count == 1)
        #expect(m.row("session")?.percent == 12)
    }
}
