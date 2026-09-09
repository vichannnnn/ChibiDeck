import Foundation
import Testing
@testable import PanelCore

@Suite struct ActionAvailabilityTests {
    static func session(kind: SessionKind, status: SessionStatus, pid: Int?) -> Session {
        Session(sessionId: "s", name: "n", cwd: "/tmp", pid: pid, kind: kind, status: status, startedAt: Date(timeIntervalSince1970: 0))
    }

    @Test func focusNeedsAnInteractiveSessionWithAPidAndAvailableActions() {
        #expect(ActionAvailability.canFocus(Self.session(kind: .interactive, status: .busy, pid: 42), actionsAvailable: true))
        #expect(!ActionAvailability.canFocus(Self.session(kind: .interactive, status: .busy, pid: 42), actionsAvailable: false))
        #expect(!ActionAvailability.canFocus(Self.session(kind: .interactive, status: .busy, pid: nil), actionsAvailable: true))
        #expect(!ActionAvailability.canFocus(Self.session(kind: .background, status: .blocked, pid: nil), actionsAvailable: true))
    }

    @Test func answerNeedsWaitingOrIdle() {
        #expect(ActionAvailability.canAnswer(Self.session(kind: .interactive, status: .waiting, pid: 42), actionsAvailable: true))
        #expect(ActionAvailability.canAnswer(Self.session(kind: .interactive, status: .idle, pid: 42), actionsAvailable: true))
        #expect(!ActionAvailability.canAnswer(Self.session(kind: .interactive, status: .busy, pid: 42), actionsAvailable: true))
        #expect(!ActionAvailability.canAnswer(Self.session(kind: .interactive, status: .idle, pid: 42), actionsAvailable: false))
        #expect(!ActionAvailability.canAnswer(Self.session(kind: .background, status: .idle, pid: nil), actionsAvailable: true))
    }

    @Test func handoffNeedsFocusAndNoRunningSequence() {
        #expect(ActionAvailability.canHandoff(Self.session(kind: .interactive, status: .busy, pid: 42), actionsAvailable: true, running: false))
        #expect(ActionAvailability.canHandoff(Self.session(kind: .interactive, status: .idle, pid: 42), actionsAvailable: true, running: false))
        #expect(!ActionAvailability.canHandoff(Self.session(kind: .interactive, status: .idle, pid: 42), actionsAvailable: true, running: true))
        #expect(!ActionAvailability.canHandoff(Self.session(kind: .interactive, status: .idle, pid: 42), actionsAvailable: false, running: false))
        #expect(!ActionAvailability.canHandoff(Self.session(kind: .background, status: .idle, pid: nil), actionsAvailable: true, running: false))
        for status in [SessionStatus.waiting, .blocked, .shell, .unknown] {   // Enter into a dialog would answer it
            #expect(!ActionAvailability.canHandoff(Self.session(kind: .interactive, status: status, pid: 42), actionsAvailable: true, running: false))
        }
    }
}
