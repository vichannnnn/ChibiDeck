import Foundation
import Testing
@testable import PanelCore

@Suite struct StateChangeTests {
    static let now = Date(timeIntervalSince1970: 1_788_660_000)
    static func session(_ name: String, pid: Int, _ status: SessionStatus) -> Session {
        Session(sessionId: "id-\(name)", name: name, cwd: "/x", pid: pid, kind: .interactive, status: status, startedAt: now.addingTimeInterval(-600))
    }
    static func inputs(status: SessionStatus = .busy, percent: Double = 10, lastActivity: TimeInterval = 0,
                       listingSuccess: TimeInterval = -3, limitsFetchedAt: TimeInterval = 0) -> RawInputs {
        RawInputs(
            listedSessions: [session("a", pid: 1, status), session("b", pid: 2, .idle)],
            lastListingSuccess: now.addingTimeInterval(listingSuccess),
            limits: Limits(fiveHour: LimitWindow(utilization: 16, resetsAt: nil), sevenDay: nil, fetchedAt: now.addingTimeInterval(limitsFetchedAt)),
            details: ["id-a": SessionDetail(contextPercent: percent, costUSD: percent, lastActivity: now.addingTimeInterval(lastActivity))]
        )
    }

    @Test func detailChurnDoesNotCountAsAStateChange() {
        let a = StateChange.sessionSignature(StateBuilder.build(Self.inputs(), now: Self.now))
        let b = StateChange.sessionSignature(StateBuilder.build(Self.inputs(percent: 91, lastActivity: -120, limitsFetchedAt: -900),
                                                                now: Self.now.addingTimeInterval(60)))
        #expect(a == b)
    }

    @Test func stalenessDoesNotCountAsAStateChange() {
        let fresh = StateBuilder.build(Self.inputs(), now: Self.now)
        let stale = StateBuilder.build(Self.inputs(listingSuccess: -45), now: Self.now)
        #expect(!fresh.isStale && stale.isStale)
        #expect(StateChange.sessionSignature(fresh) == StateChange.sessionSignature(stale))
    }

    @Test func statusChangeIsAStateChange() {
        let busy = StateChange.sessionSignature(StateBuilder.build(Self.inputs(status: .busy), now: Self.now))
        let waiting = StateChange.sessionSignature(StateBuilder.build(Self.inputs(status: .waiting), now: Self.now))
        #expect(busy != waiting)
    }

    @Test func waitingReasonAndSessionCountAreParts() {
        var asked = Self.inputs(status: .waiting)
        asked.filePatches = [1: SessionFileRecord(pid: 1, sessionId: "id-a", name: nil, cwd: nil, status: .waiting, waitingFor: "run tests?",
                                                  startedAt: nil, updatedAt: Self.now, statusUpdatedAt: Self.now)]
        let plain = StateChange.sessionSignature(StateBuilder.build(Self.inputs(status: .waiting), now: Self.now))
        #expect(StateChange.sessionSignature(StateBuilder.build(asked, now: Self.now)) != plain)

        var extra = Self.inputs(status: .waiting)
        extra.listedSessions.append(Self.session("c", pid: 3, .idle))
        #expect(StateChange.sessionSignature(StateBuilder.build(extra, now: Self.now)) != plain)
    }

    @Test func hiddenSessionCountIsPartOfTheSignature() {
        var nine = RawInputs(listedSessions: (0..<9).map { Self.session("s\($0)", pid: 100 + $0, .idle) })
        let a = StateChange.sessionSignature(StateBuilder.build(nine, now: Self.now))
        nine.listedSessions.removeLast()
        let b = StateChange.sessionSignature(StateBuilder.build(nine, now: Self.now))
        #expect(a.hiddenSessionCount == 1 && b.hiddenSessionCount == 0)
        #expect(a != b)
    }
}
