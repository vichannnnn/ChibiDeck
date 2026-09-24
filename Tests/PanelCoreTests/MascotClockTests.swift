import Foundation
import Testing
@testable import PanelCore

@Suite struct MascotClockTests {
    @Test func theTickCountsQuarterSecondsOnTheWallClock() {
        #expect(MascotClock.tick(at: 100) == 400)
        #expect(MascotClock.tick(at: 100.2) == 400)
        #expect(MascotClock.tick(at: 100.25) == 401)
        #expect(MascotClock.tick(at: 100.99) == 403)
    }

    @Test func theNextTickIsTheNextQuarterBoundary() {
        let mid = MascotClock.next(after: 100.1)
        #expect(mid.tick == 401)
        #expect(abs(mid.delay - 0.15) < 1e-9)
        let onBoundary = MascotClock.next(after: 100.25)            // exactly on a boundary: wait a whole frame, not zero
        #expect(onBoundary.tick == 402)
        #expect(abs(onBoundary.delay - 0.25) < 1e-9)
    }

    @Test func theFrameWrapsAroundTheLoop() {
        #expect(MascotClock.frame(tick: 401, count: 8) == 1)
        #expect(MascotClock.frame(tick: 407, count: 8) == 7)
        #expect(MascotClock.frame(tick: 408, count: 8) == 0)
        #expect(MascotClock.frame(tick: 5, count: 0) == 0)
    }
}
