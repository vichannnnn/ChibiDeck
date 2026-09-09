import Foundation

/// State machine over the Edge's single-touch mouse-interface reports.
public final class TouchReportParser {
    private var isTouching = false
    private var lastX: Int?
    private var lastY: Int?

    public init() {}

    public func reset() { isTouching = false; lastX = nil; lastY = nil }

    public func parse(reportID: Int, bytes: [UInt8], time: TimeInterval) -> TouchEvent? {
        guard reportID == XeneonEdgeDevice.touchReportID, bytes.count >= XeneonEdgeDevice.touchReportLength else { return nil }
        let down = bytes[1] != 0
        let x = Int(bytes[2]) | (Int(bytes[3]) << 8)
        let y = Int(bytes[4]) | (Int(bytes[5]) << 8)
        defer { isTouching = down; lastX = x; lastY = y }
        switch (isTouching, down) {
        case (false, true): return TouchEvent(kind: .down, rawX: x, rawY: y, time: time)
        case (true, true): return (x != lastX || y != lastY) ? TouchEvent(kind: .move, rawX: x, rawY: y, time: time) : nil
        case (true, false): return TouchEvent(kind: .up, rawX: x, rawY: y, time: time)
        case (false, false): return nil
        }
    }
}
