import Foundation

public struct Tap: Sendable, Equatable {
    public let rawX: Int
    public let rawY: Int
    public let time: TimeInterval
    public init(rawX: Int, rawY: Int, time: TimeInterval) { self.rawX = rawX; self.rawY = rawY; self.time = time }
}

/// Down then up within 400 ms and 24 pt (≈153 raw units at 2560 pt wide) is a tap. Everything else is dropped.
public final class TapRecognizer {
    public static let maxDuration: TimeInterval = 0.4
    public static let maxRawMovement = Int(24.0 / 2560.0 * Double(XeneonEdgeDevice.rawXMax))   // 153

    private var downEvent: TouchEvent?

    public init() {}

    public func handle(_ event: TouchEvent) -> Tap? {
        switch event.kind {
        case .down:
            downEvent = event
            return nil
        case .move:
            return nil
        case .up:
            defer { downEvent = nil }
            guard let down = downEvent else { return nil }
            let dt = event.time - down.time
            let moved = max(abs(event.rawX - down.rawX), abs(event.rawY - down.rawY))
            guard dt <= Self.maxDuration, moved <= Self.maxRawMovement else { return nil }
            return Tap(rawX: down.rawX, rawY: down.rawY, time: event.time)
        }
    }
}
