import Foundation
import PanelCore

enum ClaudePaths {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let claudeDir = home.appendingPathComponent(".claude")
    static let sessionsDir = claudeDir.appendingPathComponent("sessions")
    static let configFile = home.appendingPathComponent(".claude.json")
    static let statsCache = claudeDir.appendingPathComponent("stats-cache.json")
    static let settingsFile = claudeDir.appendingPathComponent("settings.json")
    /// Plan 3 §8.1: the statusline hook writes here, inside the app's own folder, so the app may prune it.
    static let statuslineFeedDir = appSupportDir.appendingPathComponent("statusline")
    static let tasksDir = claudeDir.appendingPathComponent("tasks")
    static let jobsDir = claudeDir.appendingPathComponent("jobs")
    static let projectsDir = claudeDir.appendingPathComponent("projects")

    /// The only place the app writes (spec 2026-09-07 §3.4): its own folder under Application Support.
    static var appSupportDir: URL { legacyMove.dir }
    /// True when this launch moved the pre-rename folder over (logged by `AppDelegate`).
    static var movedLegacyAppSupportFolder: Bool { legacyMove.moved }

    /// Rename of 2026-09-08: the folder was `CorsairDisplay`. Moved on first access, before anything can create the
    /// new folder (AppModel builds the BurnIndexer and the feed directory during init), so the burn index and the
    /// feed files carry over.
    private static let legacyMove: (dir: URL, moved: Bool) = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? home.appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("ChibiDeck")
        let legacy = base.appendingPathComponent("CorsairDisplay")
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacy.path), !fm.fileExists(atPath: dir.path) else { return (dir, false) }
        do { try fm.moveItem(at: legacy, to: dir); return (dir, true) } catch { return (dir, false) }
    }()
    static let burnIndexFile = appSupportDir.appendingPathComponent("burn-index.json")

    static func transcriptURL(cwd: String, sessionId: String) -> URL {
        TranscriptTail.transcriptURL(cwd: cwd, sessionId: sessionId, home: home)
    }

    /// `~/.claude/jobs/<id>/state.json`, keyed by the listing's own job id and falling back to the first eight
    /// characters of the session id (they coincide: job `1a2b3c4d` ↔ session `1a2b3c4d-0000-…`).
    static func jobStateFile(for session: Session) -> URL {
        jobsDir.appendingPathComponent(session.jobId ?? String(session.sessionId.prefix(8))).appendingPathComponent("state.json")
    }

    static func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// Plan 3 §8.1: feed files older than `maxAge` are deleted at launch. This folder is the app's own.
    static func pruneStatuslineFeed(now: Date = Date(), maxAge: TimeInterval = 24 * 3600) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: statuslineFeedDir.path)) ?? []
        for name in names where name.hasSuffix(".json") {
            let url = statuslineFeedDir.appendingPathComponent(name)
            if let m = modificationDate(url), now.timeIntervalSince(m) > maxAge { try? FileManager.default.removeItem(at: url) }
        }
    }
}
