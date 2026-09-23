import Foundation

/// Spec 2026-09-23 §8.2: the session grid's scroll geometry, in canvas points. Rows of `columns` cards at `rowPitch`;
/// the viewport shows `visibleRows` rows (`viewportHeight`, canvas y 80–700). The offset is 0 at the top and, at rest,
/// a multiple of `rowPitch`. Pure, so the numbers are tested and the view only applies them.
public enum GridScroll {
    public static let columns = 4
    public static let cardHeight = 300.0
    public static let rowPitch = 316.0
    public static let viewportHeight = 620.0
    public static let visibleRows = 2
    /// A release at least this fast (points per second) moves on to the next row in its direction.
    public static let flickSpeed = 600.0

    public static func rows(count: Int) -> Int { max(0, count + columns - 1) / columns }

    public static func maxOffset(count: Int) -> Double {
        Double(max(0, rows(count: count) - visibleRows)) * rowPitch
    }

    public static func clamp(_ offset: Double, count: Int) -> Double {
        min(max(offset, 0), maxOffset(count: count))
    }

    /// Where a released drag comes to rest. `speed` is the offset's rate of change at release, positive while the
    /// offset rises (the finger moving towards the top of the strip): the nearest row, or for a flick the next row in
    /// the direction the offset was moving.
    public static func snap(_ offset: Double, speed: Double, count: Int) -> Double {
        let rowsDown = clamp(offset, count: count) / rowPitch
        let target: Double
        if speed >= flickSpeed { target = (rowsDown - 1e-6).rounded(.up) }
        else if speed <= -flickSpeed { target = (rowsDown + 1e-6).rounded(.down) }
        else { target = rowsDown.rounded() }
        return clamp(target * rowPitch, count: count)
    }

    /// Sessions whose card lies wholly above the viewport.
    public static func above(offset: Double, count: Int) -> Int {
        guard offset >= cardHeight else { return 0 }
        let fullRows = Int(((offset - cardHeight) / rowPitch).rounded(.down)) + 1
        return min(count, fullRows * columns)
    }

    /// Sessions whose card lies wholly below the viewport.
    public static func below(offset: Double, count: Int) -> Int {
        let firstRow = Int(((offset + viewportHeight) / rowPitch).rounded(.up))
        return max(0, count - firstRow * columns)
    }

    /// Spec 2026-09-23 §8.5: whether a session above the viewport waits for the user (waiting or blocked, not dismissed).
    public static func attentionAbove(offset: Double, sessions: [Session], dismissed: Set<DismissKey>) -> Bool {
        sessions.prefix(above(offset: offset, count: sessions.count)).contains {
            $0.status.needsAttention && !AttentionResolver.isDismissed($0, dismissed: dismissed)
        }
    }
}
