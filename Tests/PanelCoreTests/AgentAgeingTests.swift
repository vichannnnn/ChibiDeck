import Foundation
import Testing
@testable import PanelCore

@Suite struct AgentAgeingTests {
    static let now = Date(timeIntervalSince1970: 1_788_728_400)   // 2026-09-06 05:00 UTC
    static func agent(_ name: String, kind: SessionKind, startedHoursAgo: Double) -> Session {
        Session(sessionId: "id-\(name)", name: name, cwd: "/x", pid: kind == .interactive ? 1 : nil, kind: kind,
                status: .blocked, startedAt: now.addingTimeInterval(-startedHoursAgo * 3600))
    }
    static func job(updatedHoursAgo: Double) -> JobInfo { JobInfo(updatedAt: now.addingTimeInterval(-updatedHoursAgo * 3600)) }

    @Test func dropsBackgroundAgentsOlderThanTheLimit() {
        let fresh = Self.agent("fresh", kind: .background, startedHoursAgo: 40)
        let old = Self.agent("old", kind: .background, startedHoursAgo: 40)
        let jobs = ["id-fresh": Self.job(updatedHoursAgo: 23), "id-old": Self.job(updatedHoursAgo: 25)]
        let kept = AgentAgeing.filter([fresh, old], jobs: jobs, maxAgeHours: 24, now: Self.now)
        #expect(kept.map(\.name) == ["fresh"])
    }

    @Test func fallsBackToStartedAtWithoutAJobFile() {
        let recent = Self.agent("recent", kind: .background, startedHoursAgo: 2)
        let ancient = Self.agent("ancient", kind: .background, startedHoursAgo: 1_300)
        #expect(AgentAgeing.filter([recent, ancient], jobs: [:], maxAgeHours: 24, now: Self.now).map(\.name) == ["recent"])
    }

    @Test func interactiveSessionsAreNeverAged() {
        let long = Self.agent("long", kind: .interactive, startedHoursAgo: 900)
        #expect(AgentAgeing.filter([long], jobs: [:], maxAgeHours: 24, now: Self.now).count == 1)
    }

    @Test func zeroDisablesAgeing() {
        let ancient = Self.agent("ancient", kind: .background, startedHoursAgo: 1_300)
        #expect(AgentAgeing.filter([ancient], jobs: [:], maxAgeHours: 0, now: Self.now).count == 1)
    }

    @Test func boundaryIsInclusive() {
        let edge = Self.agent("edge", kind: .background, startedHoursAgo: 24)
        #expect(AgentAgeing.filter([edge], jobs: [:], maxAgeHours: 24, now: Self.now).count == 1)
    }
}
