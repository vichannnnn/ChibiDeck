import Foundation
import Testing
@testable import PanelCore

@Suite struct TouchTests {
    // Report id 7, 7 bytes: [id, isDown, xLo, xHi, yLo, yHi, pad]. Raw grid 16384×9600.
    static func report(down: Bool, x: Int, y: Int) -> [UInt8] {
        [7, down ? 1 : 0, UInt8(x & 0xFF), UInt8(x >> 8), UInt8(y & 0xFF), UInt8(y >> 8), 0]
    }

    @Test func parsesDownMoveUp() {
        let p = TouchReportParser()
        #expect(p.parse(reportID: 7, bytes: Self.report(down: true, x: 100, y: 200), time: 0)?.kind == .down)
        #expect(p.parse(reportID: 7, bytes: Self.report(down: true, x: 100, y: 200), time: 0.01) == nil)      // identical → no move
        let move = p.parse(reportID: 7, bytes: Self.report(down: true, x: 120, y: 200), time: 0.02)
        #expect(move?.kind == .move && move?.rawX == 120)
        let up = p.parse(reportID: 7, bytes: Self.report(down: false, x: 120, y: 200), time: 0.03)
        #expect(up?.kind == .up)
        #expect(p.parse(reportID: 7, bytes: Self.report(down: false, x: 120, y: 200), time: 0.04) == nil)     // still up → nothing
    }

    @Test func ignoresOtherReportsAndShortReports() {
        let p = TouchReportParser()
        #expect(p.parse(reportID: 1, bytes: Self.report(down: true, x: 1, y: 1), time: 0) == nil)
        #expect(p.parse(reportID: 7, bytes: [7, 1, 0], time: 0) == nil)
    }

    @Test func decodesFullRange() {
        let p = TouchReportParser()
        let e = p.parse(reportID: 7, bytes: Self.report(down: true, x: 16383, y: 9599), time: 0)
        #expect(e?.rawX == 16383 && e?.rawY == 9599)
    }

    @Test func mapsCornersAndCentre() {
        let size = (width: 2560.0, height: 720.0)
        let tl = CoordinateMapper.map(rawX: 0, rawY: 0, to: size, calibration: .identity)
        let br = CoordinateMapper.map(rawX: 16383, rawY: 9599, to: size, calibration: .identity)
        let c = CoordinateMapper.map(rawX: 8192, rawY: 4800, to: size, calibration: .identity)
        #expect(tl.x == 0 && tl.y == 0)
        #expect(abs(br.x - 2560) < 0.001 && abs(br.y - 720) < 0.001)
        #expect(abs(c.x - 1280) < 1 && abs(c.y - 360) < 1)
    }

    @Test func clampsAndAppliesCalibration() {
        let size = (width: 2560.0, height: 720.0)
        let cal = TouchCalibration(offsetX: 10, offsetY: -5, scaleX: 1.1, scaleY: 0.9)
        let p = CoordinateMapper.map(rawX: 16383, rawY: 0, to: size, calibration: cal)
        #expect(p.x == 2560)          // 2560*1.1+10 clamped
        #expect(p.y == 0)             // 0*0.9-5 clamped
    }

    @Test func recognisesATap() {
        let r = TapRecognizer()
        #expect(r.handle(TouchEvent(kind: .down, rawX: 1000, rawY: 500, time: 1.0)) == nil)
        #expect(r.handle(TouchEvent(kind: .move, rawX: 1020, rawY: 505, time: 1.1)) == nil)
        let tap = r.handle(TouchEvent(kind: .up, rawX: 1020, rawY: 505, time: 1.2))
        #expect(tap == Tap(rawX: 1000, rawY: 500, time: 1.2))
    }

    @Test func rejectsSlowOrLongTouches() {
        let r = TapRecognizer()
        _ = r.handle(TouchEvent(kind: .down, rawX: 0, rawY: 0, time: 0))
        #expect(r.handle(TouchEvent(kind: .up, rawX: 0, rawY: 0, time: 0.5)) == nil)      // too slow
        _ = r.handle(TouchEvent(kind: .down, rawX: 0, rawY: 0, time: 2))
        #expect(r.handle(TouchEvent(kind: .up, rawX: 400, rawY: 0, time: 2.1)) == nil)    // moved 400 raw > 153
        #expect(r.handle(TouchEvent(kind: .up, rawX: 0, rawY: 0, time: 3)) == nil)        // up without down
    }

    @Test func longPressFiresAtTheDeadlineWhileHeld() {
        let r = LongPressRecognizer()
        #expect(r.handle(TouchEvent(kind: .down, rawX: 1000, rawY: 500, time: 1.0)) == nil)
        #expect(r.deadline == 1.5)
        _ = r.handle(TouchEvent(kind: .move, rawX: 1100, rawY: 560, time: 1.2))            // 100 raw < 153: a resting finger's jitter
        #expect(r.deadline == 1.5)                                                           // still armed
        #expect(r.fire(at: 1.4) == nil)                                                     // too early
        #expect(r.fire(at: 1.5) == LongPress(rawX: 1000, rawY: 500, time: 1.5))
        #expect(r.deadline == nil)
        #expect(r.fire(at: 1.6) == nil)                                                     // fires once
        #expect(r.handle(TouchEvent(kind: .up, rawX: 1005, rawY: 502, time: 2.4)) == nil)   // the release after a fired press is nothing
    }

    @Test func longPressOnALateRelease() {
        let r = LongPressRecognizer()
        let tap = TapRecognizer()
        let down = TouchEvent(kind: .down, rawX: 300, rawY: 300, time: 2.0)
        let up = TouchEvent(kind: .up, rawX: 310, rawY: 300, time: 2.7)
        _ = r.handle(down); _ = tap.handle(down)
        #expect(r.handle(up) == LongPress(rawX: 300, rawY: 300, time: 2.7))
        #expect(tap.handle(up) == nil)                                                       // never also a tap
        #expect(r.deadline == nil)
    }

    @Test func movementOrAnEarlyReleaseCancelsTheLongPress() {
        let r = LongPressRecognizer()
        _ = r.handle(TouchEvent(kind: .down, rawX: 0, rawY: 0, time: 0))
        _ = r.handle(TouchEvent(kind: .move, rawX: 400, rawY: 0, time: 0.1))                 // 400 raw > 153
        #expect(r.deadline == nil)
        #expect(r.fire(at: 0.6) == nil)
        #expect(r.handle(TouchEvent(kind: .up, rawX: 400, rawY: 0, time: 0.7)) == nil)
        _ = r.handle(TouchEvent(kind: .down, rawX: 0, rawY: 0, time: 5))
        #expect(r.handle(TouchEvent(kind: .up, rawX: 0, rawY: 0, time: 5.2)) == nil)          // a tap, not a hold
        #expect(r.deadline == nil)
        #expect(r.fire(at: 5.6) == nil)
    }

    @Test func aSecondDownReArmsAndResetForgets() {
        let r = LongPressRecognizer()
        _ = r.handle(TouchEvent(kind: .down, rawX: 0, rawY: 0, time: 0))
        _ = r.handle(TouchEvent(kind: .down, rawX: 50, rawY: 60, time: 3))
        #expect(r.deadline == 3.5)
        #expect(r.fire(at: 3.5) == LongPress(rawX: 50, rawY: 60, time: 3.5))
        _ = r.handle(TouchEvent(kind: .down, rawX: 0, rawY: 0, time: 9))
        r.reset()
        #expect(r.deadline == nil)
        #expect(r.fire(at: 9.5) == nil)
    }
}
