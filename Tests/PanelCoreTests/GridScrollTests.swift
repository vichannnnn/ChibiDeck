import Foundation
import Testing
@testable import PanelCore

@Suite struct GridScrollTests {
    @Test func maximumOffsetGrowsARowPerFourSessionsPastEight() {
        #expect(GridScroll.maxOffset(count: 0) == 0)
        #expect(GridScroll.maxOffset(count: 8) == 0)
        #expect(GridScroll.maxOffset(count: 9) == 316)
        #expect(GridScroll.maxOffset(count: 12) == 316)
        #expect(GridScroll.maxOffset(count: 13) == 632)
    }

    @Test func clampKeepsTheOffsetOnTheGrid() {
        #expect(GridScroll.clamp(-40, count: 13) == 0)
        #expect(GridScroll.clamp(700, count: 13) == 632)
        #expect(GridScroll.clamp(632, count: 9) == 316)          // sessions left while scrolled: back inside the grid
        #expect(GridScroll.clamp(150, count: 8) == 0)
    }

    @Test func aSlowReleaseSnapsToTheNearestRow() {
        #expect(GridScroll.snap(100, speed: 0, count: 13) == 0)
        #expect(GridScroll.snap(200, speed: 0, count: 13) == 316)
        #expect(GridScroll.snap(500, speed: -300, count: 13) == 632)
        #expect(GridScroll.snap(500, speed: 0, count: 9) == 316)
    }

    @Test func aFlickMovesAtLeastOneRowInItsDirection() {
        #expect(GridScroll.snap(20, speed: 600, count: 13) == 316)
        #expect(GridScroll.snap(340, speed: 900, count: 13) == 632)
        #expect(GridScroll.snap(600, speed: -600, count: 13) == 316)
        #expect(GridScroll.snap(290, speed: -900, count: 13) == 0)
        #expect(GridScroll.snap(20, speed: 900, count: 8) == 0)   // nothing to scroll to
    }

    @Test func countsSessionsWhollyAboveAndBelowTheViewport() {
        #expect(GridScroll.above(offset: 0, count: 13) == 0 && GridScroll.below(offset: 0, count: 13) == 5)
        #expect(GridScroll.above(offset: 316, count: 13) == 4 && GridScroll.below(offset: 316, count: 13) == 1)
        #expect(GridScroll.above(offset: 632, count: 13) == 8 && GridScroll.below(offset: 632, count: 13) == 0)
        #expect(GridScroll.above(offset: 150, count: 13) == 0 && GridScroll.below(offset: 150, count: 13) == 1)   // mid-drag
        #expect(GridScroll.below(offset: 0, count: 6) == 0)
        #expect(GridScroll.above(offset: 0, count: 0) == 0 && GridScroll.below(offset: 0, count: 0) == 0)
    }

    @Test func attentionAboveLooksOnlyAtSessionsScrolledPast() {
        func s(_ n: Int, _ status: SessionStatus) -> Session {
            Session(sessionId: "id-\(n)", name: "s\(n)", cwd: "/x", pid: n, kind: .interactive, status: status,
                    startedAt: .distantPast, statusUpdatedAt: Date(timeIntervalSince1970: 1))
        }
        let sessions = [s(0, .waiting)] + (1..<13).map { s($0, .busy) }
        #expect(!GridScroll.attentionAbove(offset: 0, sessions: sessions, dismissed: []))
        #expect(GridScroll.attentionAbove(offset: 316, sessions: sessions, dismissed: []))
        #expect(!GridScroll.attentionAbove(offset: 316, sessions: sessions, dismissed: [DismissKey(sessions[0])]))
    }
}
