import Foundation
import Testing
@testable import PanelCore

@Suite struct AutoDimPolicyTests {
    let t0 = Date(timeIntervalSince1970: 10_000)

    @Test func dimsAfterQuietMinutes() {
        #expect(AutoDimPolicy.shouldDim(enabled: true, lastTouch: t0, lastStateChange: t0, now: t0.addingTimeInterval(601), quietMinutes: 10))
        #expect(!AutoDimPolicy.shouldDim(enabled: true, lastTouch: t0, lastStateChange: t0, now: t0.addingTimeInterval(599), quietMinutes: 10))
    }

    @Test func anyRecentActivityPreventsDim() {
        #expect(!AutoDimPolicy.shouldDim(enabled: true, lastTouch: t0.addingTimeInterval(590), lastStateChange: t0, now: t0.addingTimeInterval(601), quietMinutes: 10))
        #expect(!AutoDimPolicy.shouldDim(enabled: true, lastTouch: t0, lastStateChange: t0.addingTimeInterval(590), now: t0.addingTimeInterval(601), quietMinutes: 10))
    }

    @Test func disabledNeverDims() {
        #expect(!AutoDimPolicy.shouldDim(enabled: false, lastTouch: nil, lastStateChange: nil, now: t0.addingTimeInterval(99_999), quietMinutes: 10))
    }

    @Test func nilTimestampsCountFromNow() {
        #expect(!AutoDimPolicy.shouldDim(enabled: true, lastTouch: nil, lastStateChange: nil, now: t0, quietMinutes: 10))
        #expect(AutoDimPolicy.nextCheck(lastTouch: nil, lastStateChange: nil, now: t0, quietMinutes: 10) == 600)
        #expect(AutoDimPolicy.nextCheck(lastTouch: t0, lastStateChange: t0, now: t0.addingTimeInterval(700), quietMinutes: 10) == 1)
    }
}
