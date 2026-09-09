import Foundation
import Testing
@testable import PanelCore

@Suite struct BurnStalenessTests {
    static let t0 = Date(timeIntervalSince1970: 10_000)

    @Test func staleWhenOldOrNeverIndexed() {
        let s = BurnSummary(buckets: [], indexedAt: Self.t0, complete: true, fileCount: 1)
        #expect(!s.isStale(at: Self.t0.addingTimeInterval(4 * 60)))
        #expect(s.isStale(at: Self.t0.addingTimeInterval(6 * 60)))
        #expect(s.isStale(at: Self.t0.addingTimeInterval(2 * 60), maxAge: 60))
        #expect(BurnSummary.indexing.isStale(at: Self.t0))
    }

    @Test func stateBuilderFlagsTheChartedSummary() {
        var inputs = RawInputs()
        inputs.burn = BurnSummary(buckets: [], indexedAt: Self.t0, complete: true, fileCount: 1)
        #expect(StateBuilder.build(inputs, now: Self.t0.addingTimeInterval(60)).burnIsStale == false)
        #expect(StateBuilder.build(inputs, now: Self.t0.addingTimeInterval(10 * 60)).burnIsStale == true)
        inputs.burn = .indexing
        #expect(StateBuilder.build(inputs, now: Self.t0).burnIsStale == false)     // nothing charted yet: no cue
        inputs.burn = nil
        #expect(StateBuilder.build(inputs, now: Self.t0).burnIsStale == false)
    }
}
