import Foundation

public enum StateBuilder {
    public static func build(_ inputs: RawInputs, now: Date, calendar: Calendar = .current) -> PanelState {
        let aged = AgentAgeing.filter(inputs.listedSessions, jobs: inputs.jobs, maxAgeHours: inputs.backgroundAgentMaxAgeHours, now: now)
        let live = aged.filter { !inputs.hiddenSessionIds.contains($0.sessionId) }     // Plan 4 §5.4
        let merged = live.map { listed -> Session in
            guard let pid = listed.pid, let patch = inputs.filePatches[pid] else { return listed }
            var s = listed
            s.status = patch.status
            s.waitingFor = patch.waitingFor
            s.statusUpdatedAt = patch.statusUpdatedAt ?? patch.updatedAt
            return s
        }
        let sorted = SessionSorter.sort(merged)
        let (shown, hidden) = SessionSorter.cap(sorted, limit: 8)
        let counts = AttentionResolver.counts(sessions: sorted, dismissed: inputs.dismissed)
        let needsYou = AttentionResolver.needsYou(sessions: sorted, dismissed: inputs.dismissed)
        let pose = MascotStateResolver.pose(sessions: sorted, dismissed: inputs.dismissed, quietHours: inputs.quietHours, now: now, calendar: calendar)
        let cost = inputs.feedCostsToday.isEmpty ? nil : inputs.feedCostsToday.values.reduce(0, +)
        let limits = inputs.limits ?? .empty
        let forecasts = LimitForecast.forecasts(limits: limits, store: inputs.limitSamples, now: now)
        let readyBurn = inputs.burn.flatMap { $0.complete ? $0 : nil }
        let burnChart = readyBurn.map { BurnBucketer.chart(from: $0, now: now, calendar: calendar) }
        let todayTotals = readyBurn.map { BurnBucketer.today(from: $0, now: now, calendar: calendar) }
        return PanelState(
            sessions: shown,
            hiddenSessionCount: hidden,
            allSessions: sorted,
            details: detailsWithJobText(inputs.details, sessions: sorted, jobs: inputs.jobs),
            limits: limits,
            today: StatsCacheParser.entry(for: now, in: inputs.activity, calendar: calendar),
            todayCostUSD: cost,
            counts: counts,
            needsYou: needsYou,
            mascotPose: pose,
            isStale: StaleDetector.isStale(lastSuccess: inputs.lastListingSuccess, now: now),
            dismissed: inputs.dismissed,
            now: now,
            forecasts: forecasts,
            burn: inputs.burn,
            burnChart: burnChart,
            todayTotals: todayTotals,
            burnIsStale: readyBurn?.isStale(at: now) ?? false,
            hiddenByUser: aged.count - live.count
        )
    }

    /// Spec 2026-09-07 §2.4 rows 5–6 and §2.5: a background agent's `you:` line is the job `intent`, its
    /// `claude:` line the job `needs` (else `detail`); `suggestedReply` and `state` ride along for the sheet.
    /// Interactive sessions are returned untouched.
    static func detailsWithJobText(_ details: [String: SessionDetail], sessions: [Session], jobs: [String: JobInfo]) -> [String: SessionDetail] {
        var out = details
        for session in sessions where session.kind == .background {
            guard let job = jobs[session.sessionId] else { continue }
            var d = out[session.sessionId] ?? .empty
            if let intent = job.intent { d.lastUserPrompt = intent }
            if let claude = job.needs ?? job.detail { d.lastAssistantText = claude }
            d.suggestedReply = job.suggestedReply
            d.jobState = job.state
            out[session.sessionId] = d
        }
        return out
    }

    /// Spec §5.2: the statusline feed wins for numbers; the transcript supplies text and is the fallback for context.
    public static func mergeDetail(existing: SessionDetail, feed: StatuslineRecord?, transcript: TranscriptSummary?, tasks: [TaskItem], branch: String?) -> SessionDetail {
        var d = existing
        if let feed {
            d.modelName = feed.modelDisplayName ?? feed.modelId ?? d.modelName
            if let effort = feed.effortLevel { d.effort = effort }
            if let size = feed.contextWindowSize { d.contextWindowSize = size }
            if let used = feed.totalInputTokens { d.contextUsedTokens = used }
            if let pct = feed.usedPercentage {
                d.contextPercent = pct
                d.contextIsEstimate = false
            } else if let used = feed.totalInputTokens, let size = feed.contextWindowSize, size > 0 {
                d.contextPercent = Double(used) / Double(size) * 100
                d.contextIsEstimate = false
            }
            if let cost = feed.totalCostUSD { d.costUSD = cost }
        }
        if let transcript {
            d.pending = transcript.pending                     // Plan 4 §5.3.1: every read overwrites, so a nil clears it
            if let p = transcript.lastUserPrompt { d.lastUserPrompt = p }
            if let a = transcript.lastAssistantText { d.lastAssistantText = a }
            if let t = transcript.lastActivity { d.lastActivity = t }
            if feed == nil {
                if let model = transcript.modelId { d.modelName = model }
                if let tokens = transcript.contextTokens {
                    let guessed = d.contextWindowSize ?? ContextWindow.defaultSize(modelId: transcript.modelId, displayName: nil)
                    let size = ContextWindow.reconcile(size: guessed, observedTokens: tokens)   // spec 2026-09-07 §3.2
                    d.contextWindowSize = size
                    d.contextUsedTokens = tokens
                    d.contextPercent = min(100, Double(tokens) / Double(size) * 100)
                    d.contextIsEstimate = true
                }
            }
        }
        if !tasks.isEmpty { d.tasks = tasks }
        if let branch { d.branch = branch }
        return d
    }
}
