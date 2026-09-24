import Foundation

/// The mascot's 4 fps clock (spec 2026-09-08 §3), counted in quarter seconds on the wall clock so every mascot on
/// screen shows the same frame. The app sleeps until `next(after:)` instead of using a periodic `TimelineView`: SwiftUI
/// drives a periodic timeline under about half a second from the display link and updates the whole view graph on
/// every frame between its entries (measured 2026-09-24: 120 updates a second, 8.4 % of a core against 2.6 %).
public enum MascotClock {
    public static let ticksPerSecond = 4.0

    /// The quarter second `time` (seconds since the reference date) falls in.
    public static func tick(at time: TimeInterval) -> Int {
        Int((time * ticksPerSecond).rounded(.down))
    }

    /// The first tick after `time` and how long until it starts; a time exactly on a boundary waits a whole tick.
    public static func next(after time: TimeInterval) -> (tick: Int, delay: TimeInterval) {
        let tick = tick(at: time) + 1
        return (tick, Double(tick) / ticksPerSecond - time)
    }

    /// The sprite frame to show at `tick` in a loop of `count` frames.
    public static func frame(tick: Int, count: Int) -> Int {
        count > 0 ? ((tick % count) + count) % count : 0
    }
}
