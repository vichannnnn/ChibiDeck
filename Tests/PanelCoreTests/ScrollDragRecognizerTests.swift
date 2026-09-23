import Foundation
import Testing
@testable import PanelCore

@Suite struct ScrollDragRecognizerTests {
    static func e(_ kind: TouchEvent.Kind, _ rawX: Int, _ rawY: Int, _ time: TimeInterval) -> TouchEvent {
        TouchEvent(kind: kind, rawX: rawX, rawY: rawY, time: time)
    }
    static func run(_ events: [TouchEvent]) -> [ScrollDrag] {
        let r = ScrollDragRecognizer()
        return events.compactMap { r.handle($0) }
    }
    /// Raw units down the strip → canvas points (13.3 raw/pt).
    static func pt(_ raw: Int) -> Double { Double(raw) * 720.0 / Double(XeneonEdgeDevice.rawYMax) }

    @Test func beginsOnceTheFingerHasTravelledSixteenPoints() {
        // 200 raw tall = 15.0 pt (not yet), 214 raw = 16.05 pt
        let out = Self.run([Self.e(.down, 8000, 5000, 1.0), Self.e(.move, 8000, 4800, 1.05), Self.e(.move, 8000, 4786, 1.06)])
        #expect(out == [.began(rawX: 8000, rawY: 5000, travel: Self.pt(-214))])
    }

    @Test func reportsTravelOnEveryMoveAndTheReleaseSpeed() throws {
        let out = Self.run([Self.e(.down, 8000, 5000, 10.0), Self.e(.move, 8000, 4700, 10.05), Self.e(.move, 8000, 4400, 10.10),
                            Self.e(.move, 8000, 4000, 10.15), Self.e(.up, 8000, 3800, 10.20)])
        #expect(out.count == 4)
        #expect(out[0] == .began(rawX: 8000, rawY: 5000, travel: Self.pt(-300)))
        #expect(out[1] == .moved(travel: Self.pt(-600)))
        guard case .ended(let travel, let speed) = try #require(out.last) else { Issue.record("no end"); return }
        #expect(travel == Self.pt(-1200))
        #expect(abs(speed - (Self.pt(-1200) - Self.pt(-600)) / 0.10) < 0.001)   // the 10.10 sample opens the 100 ms window
    }

    @Test func aTenPointWiggleAndAHorizontalDragNeverBegin() {
        #expect(Self.run([Self.e(.down, 8000, 5000, 1), Self.e(.move, 8000, 4867, 1.1), Self.e(.up, 8000, 4867, 1.2)]).isEmpty)
        // 300 raw tall = 22.5 pt, 400 raw wide = 62.5 pt: not twice as far down as across
        #expect(Self.run([Self.e(.down, 8000, 5000, 1), Self.e(.move, 8400, 4700, 1.1), Self.e(.up, 8400, 4700, 1.2)]).isEmpty)
    }

    @Test func aPauseBeforeTheReleaseHasNoSpeed() throws {
        let out = Self.run([Self.e(.down, 8000, 5000, 1.0), Self.e(.move, 8000, 4000, 1.1), Self.e(.up, 8000, 4000, 1.5)])
        guard case .ended(_, let speed) = try #require(out.last) else { Issue.record("no end"); return }
        #expect(speed == 0)
    }

    @Test func aNewDownStartsOver() {
        let r = ScrollDragRecognizer()
        _ = r.handle(Self.e(.down, 8000, 5000, 1))
        #expect(r.handle(Self.e(.move, 8000, 4000, 1.1)) == .began(rawX: 8000, rawY: 5000, travel: Self.pt(-1000)))
        _ = r.handle(Self.e(.down, 100, 100, 2))                       // the up of the first drag was lost
        #expect(r.handle(Self.e(.move, 100, 150, 2.1)) == nil)         // 3.75 pt: not a drag
        #expect(r.handle(Self.e(.up, 100, 150, 2.2)) == nil)
    }

    @Test func tapAndLongPressStaySilentOnADrag() {
        let tap = TapRecognizer(), press = LongPressRecognizer()
        for e in [Self.e(.down, 8000, 5000, 1.0), Self.e(.move, 8000, 4700, 1.05), Self.e(.up, 8000, 4700, 1.1)] {
            #expect(tap.handle(e) == nil)
            #expect(press.handle(e) == nil)
        }
        #expect(press.deadline == nil)
    }
}
