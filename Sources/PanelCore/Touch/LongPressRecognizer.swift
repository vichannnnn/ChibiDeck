import Foundation

/// Plan 6 §3: where a finger was held and when the hold was recognised.
public struct LongPress: Sendable, Equatable {
    public let rawX: Int
    public let rawY: Int
    public let time: TimeInterval
    public init(rawX: Int, rawY: Int, time: TimeInterval) { self.rawX = rawX; self.rawY = rawY; self.time = time }
}

/// Plan 6 §3: a finger held 0.5 s within 24 pt is a long-press. Two ways to notice it: the caller schedules `fire(at:)` for
/// `deadline` while the finger is still down (the Edge keeps the button held), or a late `up` returns the press (the
/// timer never ran). A press is reported once; the `up` after a fired press is nothing. Every event also goes to
/// `TapRecognizer`, which drops the late `up` on its own (> 400 ms).
public final class LongPressRecognizer {
    public static let minimumDuration: TimeInterval = 0.5
    public static let maxRawMovement = TapRecognizer.maxRawMovement

    private var down: TouchEvent?
    private var fired = false
    /// The uptime at which `fire(at:)` should be called; nil while nothing is pending.
    public private(set) var deadline: TimeInterval?

    public init() {}

    public func reset() { down = nil; fired = false; deadline = nil }

    public func handle(_ event: TouchEvent) -> LongPress? {
        switch event.kind {
        case .down:
            down = event
            fired = false
            deadline = event.time + Self.minimumDuration
            return nil
        case .move:
            guard let start = down, !fired, moved(from: start, to: event) > Self.maxRawMovement else { return nil }
            down = nil
            deadline = nil
            return nil
        case .up:
            defer { down = nil; fired = false; deadline = nil }
            guard let start = down, !fired, moved(from: start, to: event) <= Self.maxRawMovement,
                  event.time - start.time >= Self.minimumDuration else { return nil }
            return LongPress(rawX: start.rawX, rawY: start.rawY, time: event.time)
        }
    }

    public func fire(at time: TimeInterval) -> LongPress? {
        guard let start = down, !fired, let deadline, time >= deadline else { return nil }
        fired = true
        self.deadline = nil
        return LongPress(rawX: start.rawX, rawY: start.rawY, time: time)
    }

    private func moved(from a: TouchEvent, to b: TouchEvent) -> Int {
        max(abs(b.rawX - a.rawX), abs(b.rawY - a.rawY))
    }
}
