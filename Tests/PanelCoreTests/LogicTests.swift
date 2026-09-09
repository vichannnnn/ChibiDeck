import Foundation
import Testing
@testable import PanelCore

@Suite struct LogicTests {
    static func s(_ name: String, _ status: SessionStatus, kind: SessionKind = .interactive, updated: TimeInterval = 0, started: TimeInterval = 0) -> Session {
        Session(sessionId: "id-\(name)", name: name, cwd: "/x", pid: kind == .interactive ? 1 : nil, kind: kind,
                status: status, startedAt: Date(timeIntervalSince1970: started), statusUpdatedAt: Date(timeIntervalSince1970: updated))
    }
    static let mixed: [Session] = [
        s("idle-old", .idle, updated: 10), s("busy-1", .busy, updated: 50), s("shell", .shell, updated: 40),
        s("wait-new", .waiting, updated: 100), s("wait-old", .waiting, updated: 20),
        s("blocked", .blocked, kind: .background, updated: 30), s("idle-new", .idle, updated: 60), s("unknown", .unknown, updated: 70),
        s("busy-2", .busy, updated: 55),
    ]

    @Test func sortsByStatusThenRecency() {
        let names = SessionSorter.sort(Self.mixed).map(\.name)
        #expect(names == ["wait-new", "wait-old", "blocked", "busy-2", "busy-1", "shell", "idle-new", "idle-old", "unknown"])
    }

    @Test func capsAtEightAndCountsHidden() {
        let (shown, hidden) = SessionSorter.cap(SessionSorter.sort(Self.mixed), limit: 8)
        #expect(shown.count == 8 && hidden == 1)
        #expect(shown.last?.name == "idle-old")
    }

    @Test func needsYouPrefersOldestWaitingThenOldestBlocked() {
        #expect(AttentionResolver.needsYou(sessions: Self.mixed, dismissed: [])?.name == "wait-old")
        let dismissedBoth: Set<DismissKey> = [DismissKey(sessionId: "id-wait-old", statusUpdatedAt: Date(timeIntervalSince1970: 20)),
                                              DismissKey(sessionId: "id-wait-new", statusUpdatedAt: Date(timeIntervalSince1970: 100))]
        #expect(AttentionResolver.needsYou(sessions: Self.mixed, dismissed: dismissedBoth)?.name == "blocked")
        #expect(AttentionResolver.needsYou(sessions: [Self.s("a", .busy)], dismissed: []) == nil)
    }

    @Test func dismissalExpiresWhenStatusChanges() {
        let stale: Set<DismissKey> = [DismissKey(sessionId: "id-wait-old", statusUpdatedAt: Date(timeIntervalSince1970: 5))]
        #expect(AttentionResolver.needsYou(sessions: Self.mixed, dismissed: stale)?.name == "wait-old")
    }

    @Test func countsGroupSessions() {
        let c = AttentionResolver.counts(sessions: Self.mixed)
        #expect(c.waiting == 2 && c.busy == 2 && c.idle == 2 && c.blocked == 1 && c.shell == 1 && c.unknown == 1)
        let line = c.line(hiddenCount: 0)
        #expect(line.map(\.label) == ["2 waiting", "2 busy", "2 idle", "1 blocked", "1 shell", "1 unknown"])
        #expect(Counts(waiting: 0, busy: 1, idle: 0, blocked: 0, shell: 0, unknown: 0).line(hiddenCount: 3).map(\.label) == ["1 busy", "+3 more"])
        #expect(AttentionResolver.counts(sessions: Self.mixed, dismissed: []).waiting == 2)
    }

    @Test func mascotPoseTable() {
        let off = QuietHours(start: (22, 0), end: (7, 0), enabled: false)
        let now = Date(timeIntervalSince1970: 1_788_660_000) // 2026-09-06 12:00 UTC
        #expect(MascotStateResolver.pose(sessions: Self.mixed, dismissed: [], quietHours: off, now: now) == .top)
        #expect(MascotStateResolver.pose(sessions: [Self.s("a", .busy), Self.s("b", .busy), Self.s("c", .busy)], dismissed: [], quietHours: off, now: now) == .fast)
        #expect(MascotStateResolver.pose(sessions: [Self.s("a", .busy), Self.s("b", .idle)], dismissed: [], quietHours: off, now: now) == .cruise)
        #expect(MascotStateResolver.pose(sessions: [Self.s("a", .shell)], dismissed: [], quietHours: off, now: now) == .cruise)
        #expect(MascotStateResolver.pose(sessions: [Self.s("a", .idle)], dismissed: [], quietHours: off, now: now) == .bored)
        #expect(MascotStateResolver.pose(sessions: [], dismissed: [], quietHours: off, now: now) == .sleep)
        let dismissed: Set<DismissKey> = [DismissKey(sessionId: "id-w", statusUpdatedAt: Date(timeIntervalSince1970: 0))]
        #expect(MascotStateResolver.pose(sessions: [Self.s("w", .waiting), Self.s("b", .busy)], dismissed: dismissed, quietHours: off, now: now) == .cruise)
    }

    @Test func quietHoursWrapMidnight() {
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        let q = QuietHours(start: (22, 0), end: (7, 0), enabled: true)
        func at(_ h: Int) -> Date { utc.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: h))! }
        #expect(q.contains(at(23), calendar: utc))
        #expect(q.contains(at(3), calendar: utc))
        #expect(!q.contains(at(12), calendar: utc))
        #expect(!QuietHours(start: (22, 0), end: (7, 0), enabled: false).contains(at(23), calendar: utc))
        #expect(MascotStateResolver.pose(sessions: [Self.s("a", .busy)], dismissed: [], quietHours: q, now: at(23), calendar: utc) == .sleep)
    }

    @Test func staleAfterThirtySeconds() {
        let t0 = Date(timeIntervalSince1970: 1000)
        #expect(!StaleDetector.isStale(lastSuccess: t0, now: t0.addingTimeInterval(29)))
        #expect(StaleDetector.isStale(lastSuccess: t0, now: t0.addingTimeInterval(31)))
        #expect(StaleDetector.isStale(lastSuccess: nil, now: t0))
    }

    @Test func needsYouIgnoresInteractiveBlockedSessions() {
        let off = QuietHours(start: (22, 0), end: (7, 0), enabled: false)
        let now = Date(timeIntervalSince1970: 1_788_660_000)
        // Interactive blocked session (should NOT trigger needsYou)
        let interactiveBlocked = [Self.s("blocked-interactive", .blocked, kind: .interactive)]
        #expect(AttentionResolver.needsYou(sessions: interactiveBlocked, dismissed: []) == nil)
        #expect(MascotStateResolver.pose(sessions: interactiveBlocked, dismissed: [], quietHours: off, now: now) == .bored)
        // Background blocked session (should trigger needsYou)
        let backgroundBlocked = [Self.s("blocked-bg", .blocked, kind: .background)]
        #expect(AttentionResolver.needsYou(sessions: backgroundBlocked, dismissed: [])?.name == "blocked-bg")
        #expect(MascotStateResolver.pose(sessions: backgroundBlocked, dismissed: [], quietHours: off, now: now) == .top)
    }

    @Test func headerLineUsesTheCardOrder() {
        let c = Counts(waiting: 1, busy: 2, idle: 1, blocked: 1, shell: 0, unknown: 0)
        #expect(c.headerLine(hiddenCount: 2).map(\.label) == ["1 waiting", "1 blocked", "2 busy", "1 idle", "+2 more"])
        #expect(Counts(waiting: 0, busy: 0, idle: 0, blocked: 0, shell: 0, unknown: 0).headerLine(hiddenCount: 0).isEmpty)
    }
}
