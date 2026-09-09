import Foundation

public enum AttentionResolver {
    public static func isDismissed(_ s: Session, dismissed: Set<DismissKey>) -> Bool {
        dismissed.contains(DismissKey(s))
    }

    /// Spec §4.1: the oldest waiting session, else the oldest blocked background agent, ignoring dismissed ones.
    public static func needsYou(sessions: [Session], dismissed: Set<DismissKey>) -> Session? {
        let live = sessions.filter { !isDismissed($0, dismissed: dismissed) }
        func oldest(_ status: SessionStatus) -> Session? {
            live.filter { $0.status == status }.min { ($0.statusUpdatedAt ?? .distantPast) < ($1.statusUpdatedAt ?? .distantPast) }
        }
        func oldestBlockedBackground() -> Session? {
            live.filter { $0.status == .blocked && $0.kind == .background }.min { ($0.statusUpdatedAt ?? .distantPast) < ($1.statusUpdatedAt ?? .distantPast) }
        }
        return oldest(.waiting) ?? oldestBlockedBackground()
    }

    /// Spec §2.7: dismissal clears a session's contribution to the waiting and blocked chips; the other groups are unaffected.
    public static func counts(sessions: [Session], dismissed: Set<DismissKey> = []) -> Counts {
        func n(_ st: SessionStatus) -> Int { sessions.filter { $0.status == st }.count }
        func attention(_ st: SessionStatus) -> Int {
            sessions.filter { $0.status == st && !isDismissed($0, dismissed: dismissed) }.count
        }
        return Counts(waiting: attention(.waiting), busy: n(.busy), idle: n(.idle), blocked: attention(.blocked), shell: n(.shell), unknown: n(.unknown))
    }
}
