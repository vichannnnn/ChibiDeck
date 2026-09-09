import Foundation
import Testing
@testable import PanelCore

@Suite struct HitTesterTests {
    static let mascot = TouchRegion(target: .mascot, frame: CGRect(x: 60, y: 40, width: 280, height: 280))
    static let card = TouchRegion(target: .card("s1"), frame: CGRect(x: 940, y: 80, width: 388, height: 300))
    static let backdrop = TouchRegion(target: .sheetBackdrop, frame: CGRect(x: 920, y: 0, width: 1640, height: 720), z: 1)
    static let back = TouchRegion(target: .sheetBack, frame: CGRect(x: 974, y: 48, width: 180, height: 72), z: 2)

    @Test func pointInsideOneRegionHitsIt() {
        #expect(HitTester.hit(x: 200, y: 180, regions: [Self.mascot, Self.card]) == .mascot)
        #expect(HitTester.hit(x: 1000, y: 200, regions: [Self.mascot, Self.card]) == .card("s1"))
    }

    @Test func outsideEveryRegionIsNil() {
        #expect(HitTester.hit(x: 500, y: 500, regions: [Self.mascot, Self.card]) == nil)
        #expect(HitTester.hit(x: 10, y: 10, regions: []) == nil)
    }

    @Test func highestZWinsWhenRegionsOverlap() {
        let all = [Self.card, Self.mascot, Self.backdrop, Self.back]
        #expect(HitTester.hit(x: 1000, y: 60, regions: all) == .sheetBack)         // z 2 over z 1 over z 0
        #expect(HitTester.hit(x: 1000, y: 200, regions: all) == .sheetBackdrop)    // z 1 over the card
        #expect(HitTester.hit(x: 1000, y: 200, regions: [Self.back, Self.backdrop, Self.card]) == .sheetBackdrop)   // order does not matter
    }

    @Test func equalZGoesToTheLastRegistered() {
        let a = TouchRegion(target: .card("a"), frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let b = TouchRegion(target: .card("b"), frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(HitTester.hit(x: 50, y: 50, regions: [a, b]) == .card("b"))
        #expect(HitTester.hit(x: 50, y: 50, regions: [b, a]) == .card("a"))
    }

    @Test func edgesAndEmptyRegions() {
        #expect(HitTester.hit(x: 60, y: 40, regions: [Self.mascot]) == .mascot)          // min edge inclusive
        #expect(HitTester.hit(x: 340, y: 320, regions: [Self.mascot]) == nil)            // max edge exclusive
        let empty = TouchRegion(target: .mascot, frame: CGRect(x: 60, y: 40, width: 0, height: 0), z: 9)
        #expect(HitTester.hit(x: 60, y: 40, regions: [empty]) == nil)
    }

    @Test func cardAnswerWinsOverItsCard() {
        let pill = TouchRegion(target: .cardAnswer("s1"), frame: CGRect(x: 1160, y: 320, width: 150, height: 44), z: 1)
        #expect(HitTester.hit(x: 1200, y: 340, regions: [Self.card, pill]) == .cardAnswer("s1"))
        #expect(HitTester.hit(x: 1000, y: 200, regions: [Self.card, pill]) == .card("s1"))
    }

    @Test func pagePillWinsOverTheBackdrop() {
        let down = TouchRegion(target: .sheetPageDown, frame: CGRect(x: 1760, y: 400, width: 80, height: 60), z: 2)
        #expect(HitTester.hit(x: 1800, y: 430, regions: [Self.backdrop, down]) == .sheetPageDown)
        #expect(HitTester.hit(x: 1800, y: 300, regions: [Self.backdrop, down]) == .sheetBackdrop)
    }

    @Test func menuRowWinsOverTheBackdropAndTheCard() {
        let backdrop = TouchRegion(target: .menuClose, frame: CGRect(x: 0, y: 0, width: 2560, height: 720), z: 2)
        let row = TouchRegion(target: .menuHide, frame: CGRect(x: 960, y: 200, width: 348, height: 60), z: 3)
        #expect(HitTester.hit(x: 1000, y: 230, regions: [Self.card, backdrop, row]) == .menuHide)
        #expect(HitTester.hit(x: 1000, y: 100, regions: [Self.card, backdrop, row]) == .menuClose)
        let handoff = TouchRegion(target: .menuHandoff, frame: CGRect(x: 960, y: 262, width: 348, height: 60), z: 3)
        #expect(HitTester.hit(x: 1000, y: 290, regions: [Self.card, backdrop, row, handoff]) == .menuHandoff)
        let sheetPill = TouchRegion(target: .sheetHandoff, frame: CGRect(x: 1200, y: 640, width: 200, height: 56), z: 1)
        #expect(HitTester.hit(x: 1250, y: 660, regions: [Self.card, sheetPill]) == .sheetHandoff)
    }
}
