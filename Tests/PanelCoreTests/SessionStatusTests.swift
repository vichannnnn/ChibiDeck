import Testing
@testable import PanelCore

@Suite struct SessionStatusTests {
    @Test func mapsClaudeStrings() {
        #expect(SessionStatus(claudeString: "waiting") == .waiting)
        #expect(SessionStatus(claudeString: "blocked") == .blocked)
        #expect(SessionStatus(claudeString: "busy") == .busy)
        #expect(SessionStatus(claudeString: "BUSY") == .busy)
        #expect(SessionStatus(claudeString: "shell") == .shell)
        #expect(SessionStatus(claudeString: "idle") == .idle)
        #expect(SessionStatus(claudeString: "something-new") == .unknown)
        #expect(SessionStatus(claudeString: nil) == .unknown)
    }

    @Test func attentionAndActivityFlags() {
        #expect(SessionStatus.waiting.needsAttention)
        #expect(SessionStatus.blocked.needsAttention)
        #expect(!SessionStatus.busy.needsAttention)
        #expect(SessionStatus.busy.isActive)
        #expect(SessionStatus.shell.isActive)
        #expect(!SessionStatus.idle.isActive)
    }

    @Test func sortRankFollowsSpecOrder() {
        let ranks = [SessionStatus.waiting, .blocked, .busy, .shell, .idle, .unknown].map(\.sortRank)
        #expect(ranks == [0, 1, 2, 3, 4, 5])
    }
}
