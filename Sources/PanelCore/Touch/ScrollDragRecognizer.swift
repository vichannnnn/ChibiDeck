import Foundation

/// Spec 2026-09-23 §8.3: what one finger drag does, in canvas points. Travel and speed are the finger's, negative
/// towards the top of the strip.
public enum ScrollDrag: Sendable, Equatable {
    /// The drag has begun; `rawX`/`rawY` is the down point (for the hit test), `travel` the vertical travel so far.
    case began(rawX: Int, rawY: Int, travel: Double)
    /// Vertical travel since the down.
    case moved(travel: Double)
    /// The release: final travel and the vertical speed over the last `speedWindow`, points per second.
    case ended(travel: Double, speed: Double)
}

/// Spec 2026-09-23 §8.3: a drag begins once the finger has travelled `minTravelPoints` vertically and at least
/// `dominance` times as far vertically as horizontally. `TapRecognizer` and `LongPressRecognizer` let go past 153 raw
/// units (about 11.5 pt down the strip), so by then neither can fire, and all four recognisers share one stream.
public final class ScrollDragRecognizer {
    public static let minTravelPoints = 16.0
    public static let dominance = 2.0
    public static let speedWindow: TimeInterval = 0.1

    private var down: TouchEvent?
    private var dragging = false
    private var samples: [(time: TimeInterval, travel: Double)] = []

    public init() {}

    public func handle(_ event: TouchEvent) -> ScrollDrag? {
        switch event.kind {
        case .down:
            down = event
            dragging = false
            samples = [(event.time, 0)]
            return nil
        case .move:
            guard let start = down else { return nil }
            let (dx, dy) = Self.points(from: start, to: event)
            samples.append((event.time, dy))
            samples.removeAll { event.time - $0.time > 2 * Self.speedWindow }
            if dragging { return .moved(travel: dy) }
            guard abs(dy) >= Self.minTravelPoints, abs(dy) >= Self.dominance * abs(dx) else { return nil }
            dragging = true
            return .began(rawX: start.rawX, rawY: start.rawY, travel: dy)
        case .up:
            defer { down = nil; dragging = false; samples = [] }
            guard let start = down, dragging else { return nil }
            let dy = Self.points(from: start, to: event).dy
            samples.append((event.time, dy))
            return .ended(travel: dy, speed: speed(at: event.time, travel: dy))
        }
    }

    /// The raw axes have different scales (6.4 raw/pt wide, 13.3 raw/pt tall), so travel is measured in canvas points.
    static func points(from a: TouchEvent, to b: TouchEvent) -> (dx: Double, dy: Double) {
        (Double(b.rawX - a.rawX) * 2560.0 / Double(XeneonEdgeDevice.rawXMax),
         Double(b.rawY - a.rawY) * 720.0 / Double(XeneonEdgeDevice.rawYMax))
    }

    /// Travel per second from the oldest sample inside the window to the release; 0 after a pause.
    private func speed(at time: TimeInterval, travel: Double) -> Double {
        guard let first = samples.first(where: { time - $0.time <= Self.speedWindow }), time > first.time else { return 0 }
        return (travel - first.travel) / (time - first.time)
    }
}
