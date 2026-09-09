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
/// vertically as horizontally, measured in canvas points (the Edge's raw axes have different scales: 13.3 raw/pt
/// tall, 6.4 raw/pt wide). A tap (≤ 24 pt) and a long press (which forgets on movement) never fire on the same
/// events, so the three recognisers can share one stream.
public final class SwipeRecognizer {
    public static let maxDuration: TimeInterval = 1.0
    public static let minTravelPoints = 80.0
    /// Vertical travel must be at least this many times the horizontal travel.
    public static let dominance = 2.0

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
            let dx = Double(event.rawX - down.rawX) * 2560.0 / Double(XeneonEdgeDevice.rawXMax)
            let dy = Double(event.rawY - down.rawY) * 720.0 / Double(XeneonEdgeDevice.rawYMax)
            return Self.classify(dx: dx, dy: dy, duration: event.time - down.time)
                .map { Swipe(direction: $0, rawX: down.rawX, rawY: down.rawY, time: event.time) }
        }
    }

    /// The rule alone, in points, so the mouse path applies it to a drag's translation: `dy` negative is towards the top.
    public static func classify(dx: Double, dy: Double, duration: TimeInterval) -> Swipe.Direction? {
        guard duration <= maxDuration, abs(dy) >= minTravelPoints, abs(dy) >= dominance * abs(dx) else { return nil }
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
