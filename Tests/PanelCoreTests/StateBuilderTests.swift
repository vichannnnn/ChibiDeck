import Foundation
import Testing
@testable import PanelCore

@Suite struct StateBuilderTests {
    static let now = Date(timeIntervalSince1970: 1_788_660_000)
    static func session(_ name: String, pid: Int?, _ status: SessionStatus, kind: SessionKind = .interactive) -> Session {
        Session(sessionId: "id-\(name)", name: name, cwd: "/Users/dev/Desktop/demo-app", pid: pid, kind: kind, status: status, startedAt: now.addingTimeInterval(-3600))
    }
    static func patch(pid: Int, _ status: SessionStatus, waitingFor: String? = nil, at: TimeInterval) -> SessionFileRecord {
        SessionFileRecord(pid: pid, sessionId: "ignored", name: nil, cwd: nil, status: status, waitingFor: waitingFor,
                          startedAt: nil, updatedAt: Date(timeIntervalSince1970: at), statusUpdatedAt: Date(timeIntervalSince1970: at))
    }
    static var inputs: RawInputs {
        RawInputs(
            listedSessions: [session("a", pid: 1, .busy), session("b", pid: 2, .idle), session("bg", pid: nil, .blocked, kind: .background)],
            filePatches: [2: patch(pid: 2, .waiting, waitingFor: "input needed", at: 1_788_659_990), 99: patch(pid: 99, .busy, at: 1)],
            lastListingSuccess: now.addingTimeInterval(-3),
            limits: Limits(fiveHour: LimitWindow(utilization: 16, resetsAt: nil), sevenDay: LimitWindow(utilization: 47, resetsAt: nil), fetchedAt: now),
            activity: [DailyActivity(date: StatsCacheParser.dateKey(now, calendar: .current), messageCount: 10, sessionCount: 3, toolCallCount: 1)],
            details: ["id-a": SessionDetail(modelName: "Fable 5.1", contextPercent: 47)],
            feedCostsToday: ["id-a": 3.5, "id-b": 0.25],
            dismissed: [],
            quietHours: QuietHours(start: (22, 0), end: (7, 0), enabled: false)
        )
    }

    @Test func patchesOverrideListingAndUnknownPidsAreIgnored() {
        let state = StateBuilder.build(Self.inputs, now: Self.now)
        #expect(state.allSessions.count == 3)
        let b = state.allSessions.first { $0.name == "b" }!
        #expect(b.status == .waiting && b.waitingFor == "input needed")
        #expect(b.statusUpdatedAt == Date(timeIntervalSince1970: 1_788_659_990))
        #expect(state.sessions.first?.name == "b")               // waiting sorts first
        #expect(state.needsYou?.name == "b")
        #expect(state.mascotPose == .top)
        #expect(state.counts == Counts(waiting: 1, busy: 1, idle: 0, blocked: 1, shell: 0, unknown: 0))
    }

    @Test func aggregatesTodayAndLimits() {
        let state = StateBuilder.build(Self.inputs, now: Self.now)
        #expect(state.todayCostUSD == 3.75)
        #expect(state.today?.sessionCount == 3)
        #expect(state.limits.fiveHour?.utilization == 16)
        #expect(!state.isStale)
        #expect(state.details["id-a"]?.contextPercent == 47)
    }

    @Test func dismissedSessionsReachTheState() {
        var inputs = Self.inputs
        let key = DismissKey(sessionId: "id-b", statusUpdatedAt: Date(timeIntervalSince1970: 1_788_659_990))
        inputs.dismissed = [key]
        let state = StateBuilder.build(inputs, now: Self.now)
        let b = state.allSessions.first { $0.name == "b" }!
        #expect(state.dismissed == [key])
        #expect(AttentionResolver.isDismissed(b, dismissed: state.dismissed))
        #expect(state.needsYou?.name != "b")
    }

    @Test func staleWhenListingIsOld() {
        var inputs = Self.inputs
        inputs.lastListingSuccess = Self.now.addingTimeInterval(-45)
        #expect(StateBuilder.build(inputs, now: Self.now).isStale)
    }

    @Test func capsAtEight() {
        var inputs = Self.inputs
        inputs.listedSessions = (0..<11).map { Self.session("s\($0)", pid: 100 + $0, .idle) }
        inputs.filePatches = [:]
        let state = StateBuilder.build(inputs, now: Self.now)
        #expect(state.sessions.count == 8 && state.hiddenSessionCount == 3 && state.allSessions.count == 11)
    }

    @Test func mergeDetailPrefersFeedOverTranscript() {
        let feed = StatuslineRecord(sessionId: "s", transcriptPath: nil, cwd: nil, modelId: "claude-fable-5-1[1m]", modelDisplayName: "Fable 5.1", effortLevel: "xhigh",
                                    contextWindowSize: 1_000_000, usedPercentage: 38.4, totalInputTokens: 384_456, totalCostUSD: 3.92, rateLimits: nil)
        let transcript = TranscriptSummary(lastUserPrompt: "hi", lastAssistantText: "hello", modelId: "claude-fable-5-1", contextTokens: 400_000, lastActivity: Self.now)
        let d = StateBuilder.mergeDetail(existing: .empty, feed: feed, transcript: transcript, tasks: [], branch: "main")
        #expect(d.modelName == "Fable 5.1" && d.contextPercent == 38.4 && d.contextIsEstimate == false && d.effort == "xhigh")
        #expect(d.contextWindowSize == 1_000_000 && d.contextUsedTokens == 384_456 && d.costUSD == 3.92)
        #expect(d.lastUserPrompt == "hi" && d.lastAssistantText == "hello" && d.branch == "main")
    }

    @Test func mergeDetailEstimatesFromTranscriptWithoutFeed() {
        let transcript = TranscriptSummary(lastUserPrompt: nil, lastAssistantText: nil, modelId: "claude-opus-5", contextTokens: 100_000, lastActivity: nil)
        let d = StateBuilder.mergeDetail(existing: .empty, feed: nil, transcript: transcript, tasks: [TaskItem(id: 1, subject: "x", status: .pending)], branch: nil)
        #expect(d.modelName == "claude-opus-5")
        #expect(d.contextWindowSize == 200_000)
        #expect(d.contextPercent == 50)
        #expect(d.contextIsEstimate)
        #expect(d.costUSD == nil)
        #expect(d.tasks.count == 1)
    }

    @Test func mergeDetailKeepsExistingWhenNothingNew() {
        let existing = SessionDetail(modelName: "Opus 5", effort: "high", contextPercent: 12, lastUserPrompt: "old")
        let d = StateBuilder.mergeDetail(existing: existing, feed: nil, transcript: nil, tasks: [], branch: nil)
        #expect(d.modelName == "Opus 5" && d.contextPercent == 12 && d.lastUserPrompt == "old" && d.effort == "high")
    }

    @Test func mergeDetailBumpsTheGuessedWindowWhenUsageExceedsIt() {
        let transcript = TranscriptSummary(lastUserPrompt: nil, lastAssistantText: nil, modelId: "claude-opus-5", contextTokens: 527_137, lastActivity: nil)
        let d = StateBuilder.mergeDetail(existing: .empty, feed: nil, transcript: transcript, tasks: [], branch: nil)
        #expect(d.contextWindowSize == 1_000_000)
        #expect(d.contextUsedTokens == 527_137)
        #expect(d.contextPercent.map { Int($0.rounded()) } == 53)
        #expect(d.contextIsEstimate)
    }

    @Test func mergeDetailTreatsFableAsOneMillion() {
        let transcript = TranscriptSummary(lastUserPrompt: nil, lastAssistantText: nil, modelId: "claude-fable-5-1", contextTokens: 140_859, lastActivity: nil)
        let d = StateBuilder.mergeDetail(existing: .empty, feed: nil, transcript: transcript, tasks: [], branch: nil)
        #expect(d.contextWindowSize == 1_000_000)
        #expect(d.contextPercent.map { Int($0.rounded()) } == 14)
    }

    @Test func agedBackgroundAgentsVanishEntirely() {
        var inputs = Self.inputs
        inputs.jobs = ["id-bg": JobInfo(state: "blocked", updatedAt: Self.now.addingTimeInterval(-57 * 86400))]
        let state = StateBuilder.build(inputs, now: Self.now)
        #expect(state.allSessions.map(\.name) == ["b", "a"])
        #expect(state.counts.blocked == 0)
        #expect(state.details["id-bg"] == nil)
        inputs.backgroundAgentMaxAgeHours = 0
        #expect(StateBuilder.build(inputs, now: Self.now).allSessions.count == 3)
    }

    @Test func jobTextFillsBackgroundAgentDetails() {
        var inputs = Self.inputs
        inputs.jobs = ["id-bg": JobInfo(state: "blocked", detail: "pilot ready", needs: "pick (1) or (2)", suggestedReply: "run the pass",
                                        intent: "look at staging", updatedAt: Self.now.addingTimeInterval(-60))]
        let d = StateBuilder.build(inputs, now: Self.now).detail(for: "id-bg")
        #expect(d.lastUserPrompt == "look at staging")
        #expect(d.lastAssistantText == "pick (1) or (2)")
        #expect(d.suggestedReply == "run the pass")
        #expect(d.jobState == "blocked")
        var noNeeds = inputs
        noNeeds.jobs = ["id-bg": JobInfo(detail: "pilot ready", updatedAt: Self.now)]
        #expect(StateBuilder.build(noNeeds, now: Self.now).detail(for: "id-bg").lastAssistantText == "pilot ready")
        #expect(StateBuilder.build(inputs, now: Self.now).detail(for: "id-a").jobState == nil)   // interactive sessions untouched
    }

    @Test func derivesForecastsAndBurnFromInputs() {
        var inputs = Self.inputs
        let rows = { (p: Int, m: Double) in
            Limits(rows: [LimitRow(id: "session", title: "5-HOUR", percent: p, resetsAt: Self.now.addingTimeInterval(4 * 3600))],
                   fetchedAt: Self.now.addingTimeInterval(m * 60))
        }
        inputs.limitSamples.record(rows(10, -10)); inputs.limitSamples.record(rows(20, -1))
        inputs.limits = rows(20, -1)
        let hour = BurnBucketer.hourStart(Self.now, calendar: .current)
        inputs.burn = BurnSummary(buckets: [HourBucket(hourStart: hour, burn: 4_000, output: 1_000, input: 100, cacheRead: 9, messages: 3)],
                                  indexedAt: Self.now, complete: true, fileCount: 2)
        let state = StateBuilder.build(inputs, now: Self.now)
        #expect(state.forecasts["session"] != nil)
        #expect(state.burnChart?.bars.count == 24)
        #expect(state.burnChart?.peak == 4_000)
        #expect(state.todayTotals?.output == 1_000 && state.todayTotals?.messages == 3)
        #expect(state.burn?.fileCount == 2)

        inputs.burn = .indexing
        let indexing = StateBuilder.build(inputs, now: Self.now)
        #expect(indexing.burnChart == nil && indexing.todayTotals == nil && indexing.burn?.complete == false)
    }

    @Test func dismissedSessionsLeaveTheHeaderCounts() {
        var inputs = Self.inputs
        let state = StateBuilder.build(inputs, now: Self.now)
        #expect(state.counts.waiting == 1 && state.counts.blocked == 1)
        inputs.dismissed = [DismissKey(sessionId: "id-b", statusUpdatedAt: Date(timeIntervalSince1970: 1_788_659_990)),
                            DismissKey(sessionId: "id-bg", statusUpdatedAt: nil)]
        let acknowledged = StateBuilder.build(inputs, now: Self.now)
        #expect(acknowledged.counts.waiting == 0 && acknowledged.counts.blocked == 0)
        #expect(acknowledged.counts.busy == 1)
        #expect(acknowledged.allSessions.count == 3)           // still live, still listed
        #expect(acknowledged.mascotPose != .top)
    }

    @Test func hiddenSessionsLeaveEveryList() {
        var inputs = Self.inputs
        inputs.hiddenSessionIds = ["id-b", "id-not-listed"]
        let state = StateBuilder.build(inputs, now: Self.now)
        #expect(!state.allSessions.contains { $0.sessionId == "id-b" })
        #expect(!state.sessions.contains { $0.sessionId == "id-b" })
        #expect(state.allSessions.count == 2 && state.sessions.count == 2)
        #expect(state.hiddenByUser == 1)                      // an id that is not listed counts for nothing
        #expect(state.hiddenSessionCount == 0)                // the "+N more" cap is a different number
        #expect(state.counts.waiting == 0)                    // b was the waiting one
        #expect(state.needsYou?.sessionId == "id-bg")         // the blocked background agent is next in line
        #expect(StateBuilder.build(Self.inputs, now: Self.now).hiddenByUser == 0)

        // Spec §10: the pose ignores hidden sessions too. With only `a` (busy) and the waiting `b`, hiding `b` leaves
        // one active session — `cruise`, not the `top` the waiting one would command.
        var onlyWaitingHidden = Self.inputs
        onlyWaitingHidden.listedSessions = [Self.session("a", pid: 1, .busy), Self.session("b", pid: 2, .idle)]
        #expect(StateBuilder.build(onlyWaitingHidden, now: Self.now).mascotPose == .top)
        onlyWaitingHidden.hiddenSessionIds = ["id-b"]
        let hiddenPose = StateBuilder.build(onlyWaitingHidden, now: Self.now)
        #expect(hiddenPose.mascotPose == .cruise)
        #expect(hiddenPose.needsYou == nil && hiddenPose.counts.waiting == 0)
    }

    @Test func mergeDetailCopiesAndClearsThePendingInput() {
        let open = TranscriptSummary(lastUserPrompt: nil, lastAssistantText: nil, modelId: nil, contextTokens: nil, lastActivity: nil,
                                     pending: .permission(tool: "Bash", summary: "ls"))
        let d1 = StateBuilder.mergeDetail(existing: .empty, feed: nil, transcript: open, tasks: [], branch: nil)
        #expect(d1.pending == .permission(tool: "Bash", summary: "ls"))
        let cleared = TranscriptSummary(lastUserPrompt: nil, lastAssistantText: nil, modelId: nil, contextTokens: nil, lastActivity: nil)
        #expect(StateBuilder.mergeDetail(existing: d1, feed: nil, transcript: cleared, tasks: [], branch: nil).pending == nil)
        #expect(StateBuilder.mergeDetail(existing: d1, feed: nil, transcript: nil, tasks: [], branch: nil).pending == d1.pending)   // no read: keep
    }
}
