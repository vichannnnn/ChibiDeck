import Foundation

public struct QuietHours: Sendable, Equatable {
    public let start: (hour: Int, minute: Int)
    public let end: (hour: Int, minute: Int)
    public let enabled: Bool

    public init(start: (Int, Int), end: (Int, Int), enabled: Bool) {
        self.start = (start.0, start.1); self.end = (end.0, end.1); self.enabled = enabled
    }

    public static func == (l: QuietHours, r: QuietHours) -> Bool {
        l.start == r.start && l.end == r.end && l.enabled == r.enabled
    }

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled else { return false }
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let now = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let s = start.hour * 60 + start.minute, e = end.hour * 60 + end.minute
        return s <= e ? (now >= s && now < e) : (now >= s || now < e)
    }
}

public enum MascotStateResolver {
    /// Spec §4.4.
    public static func pose(sessions: [Session], dismissed: Set<DismissKey>, quietHours: QuietHours, now: Date, calendar: Calendar = .current) -> MascotPose {
        if quietHours.contains(now, calendar: calendar) { return .sleep }
        if sessions.isEmpty { return .sleep }
        if AttentionResolver.needsYou(sessions: sessions, dismissed: dismissed) != nil { return .top }
        let active = sessions.filter { $0.status.isActive }.count
        if active >= 3 { return .fast }
        if active >= 1 { return .cruise }
        return .bored
    }
}
