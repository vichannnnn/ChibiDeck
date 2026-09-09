import Foundation

/// A dismissed attention state. It expires when the session's status timestamp changes.
public struct DismissKey: Sendable, Hashable {
    public let sessionId: String
    public let statusUpdatedAt: Date?
    public init(sessionId: String, statusUpdatedAt: Date?) {
        self.sessionId = sessionId
        self.statusUpdatedAt = statusUpdatedAt
    }
    public init(_ session: Session) {
        self.init(sessionId: session.sessionId, statusUpdatedAt: session.statusUpdatedAt)
    }
}

public struct Counts: Sendable, Equatable {
    public let waiting: Int, busy: Int, idle: Int, blocked: Int, shell: Int, unknown: Int
    public init(waiting: Int, busy: Int, idle: Int, blocked: Int, shell: Int, unknown: Int) {
        self.waiting = waiting; self.busy = busy; self.idle = idle; self.blocked = blocked; self.shell = shell; self.unknown = unknown
    }
    public var total: Int { waiting + busy + idle + blocked + shell + unknown }

    /// Spec §4.1: only non-zero groups, in the order waiting, busy, idle, blocked, shell, unknown, then `+N more`.
    public func line(hiddenCount: Int) -> [(label: String, status: SessionStatus)] {
        var out: [(String, SessionStatus)] = []
        for (n, status) in [(waiting, SessionStatus.waiting), (busy, .busy), (idle, .idle), (blocked, .blocked), (shell, .shell), (unknown, .unknown)] where n > 0 {
            out.append(("\(n) \(status.rawValue)", status))
        }
        if hiddenCount > 0 { out.append(("+\(hiddenCount) more", .unknown)) }
        return out.map { (label: $0.0, status: $0.1) }
    }

    /// Spec 2026-09-07 §2.4 header order: waiting, blocked, busy, shell, idle, unknown, then `+N more`.
    public func headerLine(hiddenCount: Int) -> [(label: String, status: SessionStatus)] {
        var out: [(String, SessionStatus)] = []
        for (n, status) in [(waiting, SessionStatus.waiting), (blocked, .blocked), (busy, .busy), (shell, .shell), (idle, .idle), (unknown, .unknown)] where n > 0 {
            out.append(("\(n) \(status.rawValue)", status))
        }
        if hiddenCount > 0 { out.append(("+\(hiddenCount) more", .unknown)) }
        return out.map { (label: $0.0, status: $0.1) }
    }
}

public struct PanelState: Sendable, Equatable {
    public var sessions: [Session]
    public var hiddenSessionCount: Int
    public var allSessions: [Session]
    public var details: [String: SessionDetail]
    public var limits: Limits
    public var today: DailyActivity?
    public var todayCostUSD: Double?
    public var counts: Counts
    public var needsYou: Session?
    public var mascotPose: MascotPose
    public var isStale: Bool
    /// Spec §6.3: acknowledged sessions still show, but drop out of the needs-you line, the pose and the tile glow.
    public let dismissed: Set<DismissKey>
    public var now: Date
    /// Spec 2026-09-07 §3.3: `~full by` dates keyed by limit row id.
    public var forecasts: [String: Date]
    /// Spec 2026-09-07 §3.4: the indexer's latest summary (nil before the collector has heard from it).
    public var burn: BurnSummary?
    /// Derived from `burn` at `now`; nil until a full index pass has completed.
    public var burnChart: BurnChart?
    public var todayTotals: TodayTotals?
    /// Plan 3 §9.4: true when the charted summary is older than `BurnSummary.staleAfter`.
    public var burnIsStale: Bool
    /// Plan 4 §5.4: sessions the user hid from the sheet; absent from every list above, counted here for the header.
    public var hiddenByUser: Int

    public init(sessions: [Session], hiddenSessionCount: Int, allSessions: [Session], details: [String: SessionDetail], limits: Limits,
                today: DailyActivity?, todayCostUSD: Double?, counts: Counts, needsYou: Session?, mascotPose: MascotPose, isStale: Bool,
                dismissed: Set<DismissKey> = [], now: Date, forecasts: [String: Date] = [:], burn: BurnSummary? = nil,
                burnChart: BurnChart? = nil, todayTotals: TodayTotals? = nil, burnIsStale: Bool = false, hiddenByUser: Int = 0) {
        self.sessions = sessions; self.hiddenSessionCount = hiddenSessionCount; self.allSessions = allSessions; self.details = details
        self.limits = limits; self.today = today; self.todayCostUSD = todayCostUSD; self.counts = counts; self.needsYou = needsYou
        self.mascotPose = mascotPose; self.isStale = isStale; self.dismissed = dismissed; self.now = now
        self.forecasts = forecasts; self.burn = burn; self.burnChart = burnChart; self.todayTotals = todayTotals
        self.burnIsStale = burnIsStale; self.hiddenByUser = hiddenByUser
    }

    public static func empty(now: Date) -> PanelState {
        PanelState(sessions: [], hiddenSessionCount: 0, allSessions: [], details: [:], limits: .empty, today: nil, todayCostUSD: nil,
                   counts: Counts(waiting: 0, busy: 0, idle: 0, blocked: 0, shell: 0, unknown: 0), needsYou: nil, mascotPose: .sleep, isStale: true, now: now)
    }

    public func session(id: String) -> Session? { allSessions.first { $0.sessionId == id } }
    public func detail(for id: String) -> SessionDetail { details[id] ?? .empty }
}

public struct RawInputs: Sendable, Equatable {
    public var listedSessions: [Session]
    public var filePatches: [Int: SessionFileRecord]
    public var lastListingSuccess: Date?
    public var limits: Limits?
    public var activity: [DailyActivity]
    public var details: [String: SessionDetail]
    public var feedCostsToday: [String: Double]
    public var dismissed: Set<DismissKey>
    public var quietHours: QuietHours
    /// Job files for background agents, keyed by sessionId (spec 2026-09-07 §3.1).
    public var jobs: [String: JobInfo]
    /// Setting `backgroundAgentMaxAgeHours`; 0 disables ageing.
    public var backgroundAgentMaxAgeHours: Int
    /// Spec 2026-09-07 §3.3 forecast samples.
    public var limitSamples: LimitSampleStore
    /// Spec 2026-09-07 §3.4 indexer output.
    public var burn: BurnSummary?
    /// Plan 4 §5.4: session ids hidden from the sheet; the collector drops ids that leave the listing.
    public var hiddenSessionIds: Set<String>

    public init(listedSessions: [Session] = [], filePatches: [Int: SessionFileRecord] = [:], lastListingSuccess: Date? = nil, limits: Limits? = nil,
                activity: [DailyActivity] = [], details: [String: SessionDetail] = [:], feedCostsToday: [String: Double] = [:],
                dismissed: Set<DismissKey> = [], quietHours: QuietHours = QuietHours(start: (22, 0), end: (7, 0), enabled: false),
                jobs: [String: JobInfo] = [:], backgroundAgentMaxAgeHours: Int = 24,
                limitSamples: LimitSampleStore = LimitSampleStore(), burn: BurnSummary? = nil, hiddenSessionIds: Set<String> = []) {
        self.listedSessions = listedSessions; self.filePatches = filePatches; self.lastListingSuccess = lastListingSuccess; self.limits = limits
        self.activity = activity; self.details = details; self.feedCostsToday = feedCostsToday; self.dismissed = dismissed; self.quietHours = quietHours
        self.jobs = jobs; self.backgroundAgentMaxAgeHours = backgroundAgentMaxAgeHours
        self.limitSamples = limitSamples; self.burn = burn; self.hiddenSessionIds = hiddenSessionIds
    }
}
