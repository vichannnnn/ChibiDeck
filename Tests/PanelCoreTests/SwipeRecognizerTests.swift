import Foundation
import Testing
@testable import PanelCore

@Suite struct SwipeRecognizerTests {
    static func events(dy: Int, dx: Int = 0, duration: TimeInterval = 0.4) -> [TouchEvent] {
        let x0 = 8000, y0 = 5000
        return [
            TouchEvent(kind: .down, rawX: x0, rawY: y0, time: 10.0),
            TouchEvent(kind: .move, rawX: x0 + dx / 2, rawY: y0 + dy / 2, time: 10.0 + duration / 2),
            TouchEvent(kind: .up, rawX: x0 + dx, rawY: y0 + dy, time: 10.0 + duration),
        ]
    }

    static func run(_ events: [TouchEvent]) -> Swipe? {
        let r = SwipeRecognizer()
        var out: Swipe?
        for e in events { if let s = r.handle(e) { out = s } }
        return out
    }

    @Test func fingerTowardsTheTopIsAnUpSwipeAtTheDownPoint() {
        let swipe = Self.run(Self.events(dy: -1500))
        #expect(swipe == Swipe(direction: .up, rawX: 8000, rawY: 5000, time: 10.4))
    }

    @Test func fingerTowardsTheBottomIsADownSwipe() {
        #expect(Self.run(Self.events(dy: 1500))?.direction == .down)
    }

    @Test func thresholdIsEightyPointsOfTheStripHeight() {
        #expect(Self.run(Self.events(dy: -1000)) == nil)                // 75 pt
        #expect(Self.run(Self.events(dy: -1067))?.direction == .up)     // 80.03 pt
    }

    @Test func diagonalAndSlowMovesAreNotSwipes() {
        // 1500 raw tall = 112 pt; the raw x axis is coarser (6.4 raw/pt): 900 raw = 141 pt wide, 350 raw = 55 pt.
        #expect(Self.run(Self.events(dy: -1500, dx: 900)) == nil)
        #expect(Self.run(Self.events(dy: -1500, dx: 700)) == nil)       // 109 pt wide: less than twice as tall as wide
        #expect(Self.run(Self.events(dy: -1500, dx: 350))?.direction == .up)
        #expect(Self.run(Self.events(dy: -1500, duration: 1.2)) == nil)
    }

    @Test func theRuleInPointsServesTheMousePath() {
        #expect(SwipeRecognizer.classify(dx: 10, dy: -80, duration: 0.3) == .up)
        #expect(SwipeRecognizer.classify(dx: 10, dy: 79, duration: 0.3) == nil)
        #expect(SwipeRecognizer.classify(dx: 50, dy: 90, duration: 0.3) == nil)
        #expect(SwipeRecognizer.classify(dx: 0, dy: 300, duration: 1.01) == nil)
    }

    @Test func outAndBackIsNotASwipe() {
        let r = SwipeRecognizer()
        #expect(r.handle(TouchEvent(kind: .down, rawX: 8000, rawY: 5000, time: 1)) == nil)
        #expect(r.handle(TouchEvent(kind: .move, rawX: 8000, rawY: 2000, time: 1.2)) == nil)
        #expect(r.handle(TouchEvent(kind: .up, rawX: 8000, rawY: 5100, time: 1.4)) == nil)
    }

    @Test func tapAndLongPressStaySilentOnASwipe() {
        let tap = TapRecognizer(), press = LongPressRecognizer()
        for e in Self.events(dy: -1500) {
            #expect(tap.handle(e) == nil)
            #expect(press.handle(e) == nil)
        }
        #expect(press.deadline == nil)
    }

    @Test func aTapIsNotASwipeAndASecondDownRearms() {
        let r = SwipeRecognizer()
        #expect(r.handle(TouchEvent(kind: .down, rawX: 100, rawY: 100, time: 1)) == nil)
        #expect(r.handle(TouchEvent(kind: .up, rawX: 100, rawY: 100, time: 1.1)) == nil)
        #expect(r.handle(TouchEvent(kind: .up, rawX: 100, rawY: 3000, time: 1.2)) == nil)   // no down: nothing
        #expect(r.handle(TouchEvent(kind: .down, rawX: 100, rawY: 100, time: 2)) == nil)
        #expect(r.handle(TouchEvent(kind: .up, rawX: 100, rawY: 3000, time: 2.3))?.direction == .down)
    }
}

@Suite struct SwipePagingTests {
    @Test func swipesOverTheSheetPage() {
        #expect(SwipePaging.target(for: .up, over: .sheetBackdrop) == .sheetPageDown)
        #expect(SwipePaging.target(for: .down, over: .sheetBackdrop) == .sheetPageUp)
        #expect(SwipePaging.target(for: .up, over: .sheetAnswer(0)) == .sheetPageDown)
        #expect(SwipePaging.target(for: .down, over: .sheetPageDown) == .sheetPageUp)
        #expect(SwipePaging.target(for: .up, over: .sheetHandoff) == .sheetPageDown)
        for pill in [TouchTarget.sheetBack, .sheetFocus, .sheetDismiss, .sheetHide, .sheetPageUp] {
            #expect(SwipePaging.target(for: .up, over: pill) == .sheetPageDown)
            #expect(SwipePaging.target(for: .down, over: pill) == .sheetPageUp)
        }
    }

    @Test func swipesElsewhereDoNothing() {
        #expect(SwipePaging.target(for: .up, over: .card("s1")) == nil)
        #expect(SwipePaging.target(for: .up, over: .mascot) == nil)
        #expect(SwipePaging.target(for: .down, over: .menuClose) == nil)
        #expect(SwipePaging.target(for: .down, over: nil) == nil)
    }
}
