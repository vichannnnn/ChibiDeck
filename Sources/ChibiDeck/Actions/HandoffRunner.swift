import Foundation
import PanelCore
import os

private let handoffLog = Logger(subsystem: "me.himaa.chibideck", category: "handoff")

/// Handoff §4, §6: one live sequence per pid. While any sequence is active a 2 s timer reads the pid's
/// `sessions/<pid>.json` (the clear signal is its session id changing) and, until the reply is captured, the
/// original session's transcript; each look goes to the pure `HandoffSequencer`, whose commands are carried out
/// through the bridge. Every phase change is a toast. Types nothing but `/handoff`, `/clear` and the block.
/// A block captured and then lost to a Terminal error is written under the app's own Application Support folder.
@MainActor
final class HandoffRunner {
    static let pollInterval: TimeInterval = 2

    private struct Live {
        var session: Session          // the session at the request: the bridge needs only its kind and pid
        var sequencer: HandoffSequencer
    }

    private let actions: PanelActions
    private let ui: PanelUIState
    private var live: [Int: Live] = [:]
    /// Pids whose `/handoff` is being typed right now: reserved before the await so a double tap types it once
    /// (review 2026-09-08).
    private var starting: Set<Int> = []
    private var timer: Timer?
    private var tickInFlight = false

    init(actions: PanelActions, ui: PanelUIState) {
        self.actions = actions
        self.ui = ui
    }

    func isRunning(pid: Int) -> Bool { starting.contains(pid) || live[pid]?.sequencer.isActive == true }

    /// Handoff §4: types `/handoff` and starts watching. A pid with a running sequence is refused with a toast, and
    /// so is a session whose file says it is waiting at that instant: typed text plus Enter would answer the dialog.
    func start(_ session: Session) {
        guard let pid = session.pid else { return }
        guard !isRunning(pid: pid) else { ui.toast = "handoff already running"; return }
        let status = Self.sessionRecord(pid: pid)?.status ?? session.status
        guard status == .busy || status == .idle else { ui.toast = "handoff: session is waiting"; return }
        starting.insert(pid)
        Task { @MainActor in
            defer { starting.remove(pid) }
            switch await actions.sendLine(session, text: "/handoff") {
            case .done:
                live[pid] = Live(session: session, sequencer: HandoffSequencer(pid: pid, sessionId: session.sessionId, requestedAt: Date()))
                ui.toast = "handoff requested"
                handoffLog.info("requested for pid \(pid, privacy: .public) session \(session.sessionId, privacy: .public)")
                startTimer()
            case .unavailable(let why), .failed(let why):
                ui.toast = "handoff: \(why)"
            }
        }
    }

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
    }

    private func tick() async {
        guard !tickInFlight else { return }
        tickInFlight = true
        defer { tickInFlight = false }
        for pid in live.keys.sorted() {
            guard var entry = live[pid], entry.sequencer.isActive else { live[pid] = nil; continue }
            let observation = await observe(pid: pid, session: entry.session, needsTranscript: entry.sequencer.phase == .requested)
            let command = entry.sequencer.observe(observation, now: Date())
            live[pid] = entry
            if let command { await carryOut(command, pid: pid) }
        }
        if live.values.allSatisfy({ !$0.sequencer.isActive }) {
            live.removeAll()
            timer?.invalidate()
            timer = nil
        }
    }

    private static func sessionRecord(pid: Int) -> SessionFileRecord? {
        (try? Data(contentsOf: ClaudePaths.sessionsDir.appendingPathComponent("\(pid).json"))).flatMap(SessionFileParser.parse)
    }

    private func observe(pid: Int, session: Session, needsTranscript: Bool) async -> HandoffSequencer.Observation {
        let alive = kill(pid_t(pid), 0) == 0
        let record = Self.sessionRecord(pid: pid)
        var reply: String?
        var replyAt: Date?
        if needsTranscript, record?.sessionId == session.sessionId {           // only the original transcript can carry the reply
            let url = transcriptURL(for: session)
            let summary = await Task.detached(priority: .utility) { Self.readReply(url: url) }.value
            reply = summary?.handoffReply
            replyAt = summary?.handoffReplyAt
        }
        return HandoffSequencer.Observation(pidAlive: alive, sessionId: record?.sessionId, status: record?.status,
                                            handoffReply: reply, handoffReplyAt: replyAt)
    }

    /// The cheap 512 KiB tail first; when it holds no `/handoff` record at all (the skill's tool results can run to
    /// megabytes) the 4 MiB step `TranscriptTail.readPrompt` also uses (review 2026-09-08).
    nonisolated private static func readReply(url: URL) -> TranscriptSummary? {
        let quick = TranscriptTail.read(url: url)
        if quick?.handoffRequested == true { return quick }
        return TranscriptTail.read(url: url, maxBytes: TranscriptTail.promptSteps[0]) ?? quick
    }

    /// The feed's `transcript_path` when the statusline hook wrote one, else the path Claude Code derives from the cwd
    /// (the same rule `DataCollector.refreshDetail` uses).
    private func transcriptURL(for session: Session) -> URL {
        let feedURL = ClaudePaths.statuslineFeedDir.appendingPathComponent("\(session.sessionId).json")
        if let data = try? Data(contentsOf: feedURL), let path = StatuslineParser.parse(data)?.transcriptPath {
            return URL(fileURLWithPath: path)
        }
        return ClaudePaths.transcriptURL(cwd: session.cwd, sessionId: session.sessionId)
    }

    private func carryOut(_ command: HandoffSequencer.Command, pid: Int) async {
        guard let entry = live[pid] else { return }
        switch command {
        case .typeClear:
            switch await actions.sendLine(entry.session, text: "/clear") {
            case .done:
                ui.toast = "handoff: clearing"
                handoffLog.info("captured \(entry.sequencer.block?.utf8.count ?? 0, privacy: .public) bytes for pid \(pid, privacy: .public); /clear typed")
            case .unavailable(let why), .failed(let why):
                live[pid]?.sequencer.abort(why)
                lost(why, block: entry.sequencer.block, pid: pid)
            }
        case .paste(let block):
            switch await actions.pasteBlock(entry.session, text: block) {
            case .done:
                ui.toast = "handoff pasted"
                handoffLog.info("pasted \(block.utf8.count, privacy: .public) bytes into pid \(pid, privacy: .public)")
            case .unavailable(let why), .failed(let why):
                lost(why, block: block, pid: pid)
            }
        case .fail(let why):
            lost(why, block: entry.sequencer.block, pid: pid)
        }
    }

    /// A failure with the block already captured (the session may be cleared by now): keep the block in the app's
    /// Application Support folder, the only place it writes, and say so in the toast.
    private func lost(_ why: String, block: String?, pid: Int) {
        handoffLog.error("pid \(pid, privacy: .public): \(why, privacy: .public)")
        guard let block else { ui.toast = "handoff: \(why)"; return }
        let dir = ClaudePaths.appSupportDir.appendingPathComponent("handoff")
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = dir.appendingPathComponent("\(pid)-\(stamp).txt")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try block.write(to: url, atomically: true, encoding: .utf8)
            ui.toast = "handoff: \(why) · block saved to handoff/\(url.lastPathComponent)"
            handoffLog.info("block saved to \(url.path, privacy: .public)")
        } catch {
            ui.toast = "handoff: \(why) · block lost"
            handoffLog.error("could not save the block: \(String(describing: error), privacy: .public)")
        }
    }
}
