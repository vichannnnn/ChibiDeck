import Foundation
import Observation
import PanelCore
import os

private let dataLog = Logger(subsystem: "me.himaa.chibideck", category: "data")

@MainActor @Observable
final class DataCollector {
    private(set) var state: PanelState
    private(set) var lastStateChange = Date()

    private let settings: PanelSettings
    private var inputs = RawInputs()
    private var listingTimer: Timer?
    private var clockTimer: Timer?
    private var sessionsWatcher: DirectoryWatcher?
    private var feedWatcher: DirectoryWatcher?
    private var configMTime: Date?
    private var statsMTime: Date?
    private var lastSignature: StateSignature?
    private var listingInFlight = false
    private let burnIndexer = BurnIndexer(root: ClaudePaths.projectsDir, storeURL: ClaudePaths.burnIndexFile)
    private var burnTimer: Timer?
    private var burnInFlight = false
    private var jobMTimes: [String: Date] = [:]
    private var gitChain: Task<String?, Never>?

    // Plan 3 §9.2: the only caches, all swept every tick.
    private var branchCache = ExpiringCache<String, String?>(ttl: DataCollector.branchInterval)        // keyed by cwd
    private var detailFresh = ExpiringCache<String, Bool>(ttl: DataCollector.detailInterval)           // keyed by session id
    private var deepReadAttempted = ExpiringCache<String, Bool>(ttl: DataCollector.deepReadInterval)   // keyed by session id

    static let listingInterval: TimeInterval = 5
    static let detailInterval: TimeInterval = 5
    static let burnInterval: TimeInterval = 60
    static let branchInterval: TimeInterval = 60
    static let deepReadInterval: TimeInterval = 10 * 60

    init(settings: PanelSettings) {
        self.settings = settings
        self.state = PanelState.empty(now: Date())
    }

    func start() {
        guard listingTimer == nil else { return }
        // Plan 3 §8.1: the feed folder is ours; create it so the watcher has a path, and drop stale files.
        try? FileManager.default.createDirectory(at: ClaudePaths.statuslineFeedDir, withIntermediateDirectories: true)
        ClaudePaths.pruneStatuslineFeed()
        sessionsWatcher = DirectoryWatcher(paths: [ClaudePaths.sessionsDir]) { [weak self] paths in self?.sessionFilesChanged(paths) }
        feedWatcher = DirectoryWatcher(paths: [ClaudePaths.statuslineFeedDir]) { [weak self] paths in self?.feedChanged(paths) }
        sessionsWatcher?.start()
        feedWatcher?.start()
        listingTimer = Timer.scheduledTimer(withTimeInterval: Self.listingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.rebuild(reason: nil) }
        }
        inputs.burn = .indexing                                      // spec 2026-09-07 §2.3: "indexing…" until the first pass lands
        burnTimer = Timer.scheduledTimer(withTimeInterval: Self.burnInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.runBurnPass() }
        }
        Task { await tick() }
        Task { await runBurnPass() }
    }

    func refreshNow() { Task { await tick() } }

    /// Plan 3 §9.3: called on the way out so a dirty burn index reaches disk.
    func flush() { burnIndexer.flush() }

    func dismiss(_ session: Session) {
        inputs.dismissed.insert(DismissKey(session))
        rebuild(reason: "dismiss")
    }

    /// Plan 4 §5.4: the card disappears; the id is forgotten once the session leaves the listing (`sweepCaches`).
    func hide(_ session: Session) {
        inputs.hiddenSessionIds.insert(session.sessionId)
        rebuild(reason: "hide")
    }

    /// Plan 4 §5.4: every hidden card returns (the menu item).
    func unhideAll() {
        inputs.hiddenSessionIds.removeAll()
        rebuild(reason: "unhide")
    }

    /// Loads transcript, tasks and branch for one session (used when the sheet opens).
    func ensureDetail(for sessionId: String) {
        Task { await refreshDetail(sessionId: sessionId, force: true) }
    }

    var selectedForDetail: String?

    // MARK: - Refresh loop

    private func tick() async {
        await refreshListing()
        readJobs()
        readSessionFiles()
        readConfigIfChanged()
        readStatsIfChanged()
        readFeedCosts()
        for s in state.sessions { await refreshDetail(sessionId: s.sessionId, force: false) }
        if let sel = state.allSessions.first(where: { $0.sessionId == selectedForDetail }) { await refreshDetail(sessionId: sel.sessionId, force: false) }
        sweepCaches()
        rebuild(reason: "tick")
    }

    /// Plan 3 §9.2: nothing keyed by a session outlives the listing; nothing timed outlives its TTL.
    private func sweepCaches() {
        let now = Date()
        let live = Set(inputs.listedSessions.map(\.sessionId))
        detailFresh.sweep(now: now)
        detailFresh.retain(live)
        deepReadAttempted.sweep(now: now)
        deepReadAttempted.retain(live)
        branchCache.sweep(now: now)
        jobMTimes = jobMTimes.filter { live.contains($0.key) }
        inputs.details = inputs.details.filter { live.contains($0.key) }
        inputs.hiddenSessionIds = inputs.hiddenSessionIds.filter { live.contains($0) }
    }

    private func refreshListing() async {
        guard !listingInFlight else { return }
        listingInFlight = true
        defer { listingInFlight = false }
        do {
            let data = try await ClaudeCLI.agentsJSON()
            inputs.listedSessions = try AgentsListParser.parse(data)
            inputs.lastListingSuccess = Date()
        } catch {
            dataLog.error("agents --json failed: \(String(describing: error))")
        }
    }

    /// Spec 2026-09-07 §3.1: one small file per background agent, re-parsed only when its modification date moves.
    private func readJobs() {
        var jobs: [String: JobInfo] = [:]
        for session in inputs.listedSessions where session.kind == .background {
            let url = ClaudePaths.jobStateFile(for: session)
            guard let m = ClaudePaths.modificationDate(url) else { continue }
            if jobMTimes[session.sessionId] == m, let cached = inputs.jobs[session.sessionId] {
                jobs[session.sessionId] = cached
                continue
            }
            guard let data = try? Data(contentsOf: url), let job = JobStateParser.parse(data) else { continue }
            jobs[session.sessionId] = job
            jobMTimes[session.sessionId] = m
        }
        inputs.jobs = jobs
    }

    /// Spec 2026-09-07 §3.4: never two passes at once; the indexer does the file work on its own queue.
    private func runBurnPass() async {
        guard !burnInFlight else { return }
        burnInFlight = true
        defer { burnInFlight = false }
        let summary = await burnIndexer.pass()
        if summary.complete || inputs.burn?.complete != true { inputs.burn = summary }   // keep a good summary through a transient failure
        rebuild(reason: "burn")
    }

    private func readSessionFiles() {
        var patches: [Int: SessionFileRecord] = [:]
        let names = (try? FileManager.default.contentsOfDirectory(atPath: ClaudePaths.sessionsDir.path)) ?? []
        for name in names where name.hasSuffix(".json") {
            let url = ClaudePaths.sessionsDir.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url), let rec = SessionFileParser.parse(data) else { continue }
            guard kill(pid_t(rec.pid), 0) == 0 else { continue }   // ignore files for dead pids (spec §11)
            patches[rec.pid] = rec
        }
        inputs.filePatches = patches
    }

    /// Plan 4 §5.3.1: a session whose status just became `waiting` has its transcript read at once — the answer pill
    /// must not describe the dialog before last. The read goes through `refreshDetail`, the one detail path, with the
    /// freshness entry dropped the way `feedChanged` drops it; no new timer, no second reader.
    private func sessionFilesChanged(_ paths: [String]) {
        let wasWaiting = Set(state.sessions.filter { $0.status == .waiting }.map(\.sessionId))
        readSessionFiles()
        rebuild(reason: "sessions")
        let flipped = state.sessions.filter { $0.status == .waiting && !wasWaiting.contains($0.sessionId) }.map(\.sessionId)
        guard !flipped.isEmpty else { return }
        for id in flipped { detailFresh.remove(id) }
        Task { @MainActor in
            for id in flipped { await refreshDetail(sessionId: id, force: false) }
            rebuild(reason: "waiting")
        }
    }

    /// A feed write only invalidates the sessions it names: clearing every session's detail here would spawn a
    /// `claude agents --json` pass on every statusline write. The 5 s tick picks the cleared sessions up.
    private func feedChanged(_ paths: [String]) {
        readFeedCosts()
        for path in paths {
            let name = (path as NSString).lastPathComponent
            guard name.hasSuffix(".json") else { continue }
            detailFresh.remove((name as NSString).deletingPathExtension)
        }
        rebuild(reason: "feed")
    }

    private func readConfigIfChanged() {
        let m = ClaudePaths.modificationDate(ClaudePaths.configFile)
        guard m != configMTime else { return }
        configMTime = m
        if let data = try? Data(contentsOf: ClaudePaths.configFile), let limits = UsageCacheParser.parse(data) {
            adoptLimits(limits)
        }
    }

    /// Plan 3 §8.5: every limits source is merged per row id, so a feed file that carries only the two account-wide
    /// rows can never erase the cache's scoped rows, and an older source never overwrites a newer one.
    private func adoptLimits(_ parsed: Limits) {
        let merged = (inputs.limits ?? .empty).merging(parsed)
        if merged != inputs.limits {
            let rows = merged.rows.map { "\($0.id)=\($0.percent)" }.joined(separator: " ")
            dataLog.info("limits now from \(merged.source?.rawValue ?? "?", privacy: .public): \(rows, privacy: .public)")
        }
        inputs.limits = merged
        inputs.limitSamples.record(merged)
    }

    private func readStatsIfChanged() {
        let m = ClaudePaths.modificationDate(ClaudePaths.statsCache)
        guard m != statsMTime else { return }
        statsMTime = m
        if let data = try? Data(contentsOf: ClaudePaths.statsCache) { inputs.activity = StatsCacheParser.parse(data) }
    }

    private func feedRecord(for sessionId: String) -> StatuslineRecord? {
        let url = ClaudePaths.statuslineFeedDir.appendingPathComponent("\(sessionId).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return StatuslineParser.parse(data)
    }

    /// Today's feed files give two things: each session's cost, and the `rate_limits` Claude Code refreshes from the
    /// rate-limit headers of every API response (documented statusline field). Limits are adopted whether or not the
    /// file carries a cost, so the panel's bars follow the feed and no longer wait for `/usage` to rewrite the cache.
    private func readFeedCosts() {
        var costs: [String: Double] = [:]
        let names = (try? FileManager.default.contentsOfDirectory(atPath: ClaudePaths.statuslineFeedDir.path)) ?? []
        let cal = Calendar.current
        for name in names where name.hasSuffix(".json") {
            let url = ClaudePaths.statuslineFeedDir.appendingPathComponent(name)
            guard let m = ClaudePaths.modificationDate(url), cal.isDateInToday(m),
                  let data = try? Data(contentsOf: url), let rec = StatuslineParser.parse(data, fetchedAt: m) else { continue }
            if let limits = rec.rateLimits { adoptLimits(limits) }
            if let cost = rec.totalCostUSD { costs[rec.sessionId] = cost }
        }
        inputs.feedCostsToday = costs
    }

    private func refreshDetail(sessionId: String, force: Bool) async {
        guard let session = inputs.listedSessions.first(where: { $0.sessionId == sessionId }) else { return }
        let now = Date()
        if !force, detailFresh.value(for: sessionId, now: now) != nil { return }
        detailFresh.set(true, for: sessionId, now: now)
        let feed = feedRecord(for: sessionId)
        let transcriptURL = feed?.transcriptPath.map { URL(fileURLWithPath: $0) } ?? ClaudePaths.transcriptURL(cwd: session.cwd, sessionId: sessionId)
        var transcript = await Task.detached(priority: .utility) { TranscriptTail.read(url: transcriptURL) }.value
        // Plan 3 §9.1: a tool-heavy session's last human prompt can lie megabytes before the end. Read further back
        // once (per ten minutes), and only while no prompt is known; once found it sticks through `mergeDetail`.
        if transcript != nil, transcript?.lastUserPrompt == nil, session.kind == .interactive,
           inputs.details[sessionId]?.lastUserPrompt == nil, deepReadAttempted.value(for: sessionId, now: now) == nil {
            deepReadAttempted.set(true, for: sessionId, now: now)
            if let prompt = await Task.detached(priority: .utility, operation: { TranscriptTail.readPrompt(url: transcriptURL) }).value {
                transcript?.lastUserPrompt = prompt
                dataLog.info("deep prompt read succeeded for \(sessionId, privacy: .public)")
            }
        }
        let tasks = TaskListReader.read(directory: ClaudePaths.tasksDir.appendingPathComponent(sessionId))
        let branch = await gitBranch(for: session.cwd, force: force)
        inputs.details[sessionId] = StateBuilder.mergeDetail(existing: inputs.details[sessionId] ?? .empty, feed: feed, transcript: transcript, tasks: tasks, branch: branch)
    }

    /// Spec 2026-09-07 §3.5: the branch for every shown session, cached 60 s per working directory. Every lookup
    /// awaits the previous one through `gitChain`, so at most one `git` process runs at a time no matter how many
    /// ticks or sheet openings overlap.
    private func gitBranch(for cwd: String, force: Bool) async -> String? {
        if !force, let cached = branchCache.value(for: cwd, now: Date()) { return cached }
        let previous = gitChain
        let link = Task<String?, Never> { @MainActor in
            _ = await previous?.value
            return await ClaudeCLI.gitBranch(cwd: cwd)
        }
        gitChain = link
        let result = await link.value
        branchCache.set(result, for: cwd, now: Date())
        return result
    }

    private func rebuild(reason: String?) {
        inputs.quietHours = settings.quietHours
        inputs.backgroundAgentMaxAgeHours = settings.backgroundAgentMaxAgeHours
        let next = StateBuilder.build(inputs, now: Date())
        let signature = StateChange.sessionSignature(next)
        if signature != lastSignature {                       // spec §4.6: only session state changes wake the panel
            lastSignature = signature
            lastStateChange = Date()
        }
        state = next
        if let reason { dataLog.debug("rebuild(\(reason)): \(next.allSessions.count) sessions, stale=\(next.isStale)") }
    }
}
