import Foundation

/// Sheet swipe §B: a vertical flick recognised on the release, reported at the down point.
public struct Swipe: Sendable, Equatable {
    public enum Direction: Sendable, Equatable { case up, down }
    public let direction: Direction
    public let rawX: Int
    public let rawY: Int
    public let time: TimeInterval
    public init(direction: Direction, rawX: Int, rawY: Int, time: TimeInterval) {
        self.direction = direction; self.rawX = rawX; self.rawY = rawY; self.time = time
    }
}

/// Sheet swipe §B: down, moves, up within a second, travelling at least 80 pt vertically and at least twice as far
/// vertically as horizontally. A tap (≤ 24 pt) and a long press (which forgets on movement) never fire on the same
/// events, so the three recognisers can share one stream.
public final class SwipeRecognizer {
    public static let maxDuration: TimeInterval = 1.0
    /// 80 pt of the strip's 720 pt height, in the Edge's raw units.
    public static let minTravelPoints = 80.0
    public static let minRawTravel = Int(minTravelPoints / 720.0 * Double(XeneonEdgeDevice.rawYMax))   // 1066
    /// Vertical travel must be at least this many times the horizontal travel.
    public static let dominance = 2

    private var downEvent: TouchEvent?

    public init() {}

    public func handle(_ event: TouchEvent) -> Swipe? {
        switch event.kind {
        case .down:
            downEvent = event
            return nil
        case .move:
            return nil
        case .up:
            defer { downEvent = nil }
            guard let down = downEvent else { return nil }
            return Self.classify(dx: event.rawX - down.rawX, dy: event.rawY - down.rawY, duration: event.time - down.time)
                .map { Swipe(direction: $0, rawX: down.rawX, rawY: down.rawY, time: event.time) }
        }
    }

    /// The rule alone, so the mouse path can apply it in points: `dy` negative is towards the top.
    public static func classify(dx: Int, dy: Int, duration: TimeInterval, minTravel: Int = minRawTravel) -> Swipe.Direction? {
        guard duration <= maxDuration, abs(dy) >= minTravel, abs(dy) >= dominance * abs(dx) else { return nil }
        return dy < 0 ? .up : .down
    }
}

/// Sheet swipe §B: what a swipe does, by the region under its down point. Only the sheet pages; a finger towards the
/// top of the strip reads on, like pushing the text up.
public enum SwipePaging {
    public static func target(for direction: Swipe.Direction, over target: TouchTarget?) -> TouchTarget? {
        switch target {
        case .sheetBackdrop, .sheetAnswer, .sheetBack, .sheetFocus, .sheetHandoff, .sheetDismiss, .sheetHide, .sheetPageUp, .sheetPageDown:
            return direction == .up ? .sheetPageDown : .sheetPageUp
        default:
            return nil
        }
    }
}
