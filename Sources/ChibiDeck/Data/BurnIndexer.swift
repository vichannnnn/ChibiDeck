import Foundation
import PanelCore
import os

private let burnLog = Logger(subsystem: "me.himaa.chibideck", category: "burn")

/// Spec 2026-09-07 §3.4 and Plan 3 §9.3. Walks every `*.jsonl` under `~/.claude/projects` (subagent transcripts
/// included) whose modification date is within the last 25 hours, keeps a per-file byte offset so later passes read
/// only what was appended, and persists that index under the app's own Application Support folder. It never writes
/// under `~/.claude`.
///
/// All state is confined to `queue`, a private utility queue: a 60 s first pass never occupies a thread of the
/// Swift cooperative pool or the main thread. The persisted index is restored on that queue at the start of the
/// first pass, the index is saved at most every `saveInterval` (and always after the first complete pass), and
/// `flush()` writes a dirty index synchronously so `applicationWillTerminate` can call it.
final class BurnIndexer: @unchecked Sendable {
    static let fileMaxAge: TimeInterval = 25 * 3600
    static let recordMaxAge: TimeInterval = 48 * 3600
    static let chunkBytes = 8 * 1024 * 1024
    static let saveInterval: TimeInterval = 5 * 60

    private struct Snapshot: Codable {
        var files: [String: FileBurnIndex]
        var savedAt: Date
    }

    private let queue = DispatchQueue(label: "me.himaa.chibideck.burn", qos: .utility)
    private let root: URL
    private let storeURL: URL

    // Everything below is touched only on `queue`.
    private var files: [String: FileBurnIndex] = [:]
    private var scannedMTimes: [String: Date] = [:]
    private var dirty = false
    private var restored = false
    private var lastSavedAt: Date?

    init(root: URL, storeURL: URL) {
        self.root = root
        self.storeURL = storeURL
    }

    /// One pass, run on the indexer's queue. The first pass after install reads every in-scope transcript; later
    /// passes touch only files whose modification date or size moved, and read only bytes past the stored offset.
    func pass(now: Date = Date()) async -> BurnSummary {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.runPass(now: now)) }
        }
    }

    /// Writes a dirty index now. Called from the app's `willTerminate` path.
    func flush() {
        queue.sync {
            if dirty { save(now: Date(), force: true) }
        }
    }

    private func runPass(now: Date) -> BurnSummary {
        restoreIfNeeded()
        let cutoff = now.addingTimeInterval(-Self.recordMaxAge)
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        var seen = Set<String>()
        // No projects folder at all means "no transcripts" (spec 2026-09-07 §5) — a real, complete answer.
        guard FileManager.default.fileExists(atPath: root.path) else {
            return BurnSummary(buckets: [], indexedAt: now, complete: true, fileCount: 0)
        }
        // The folder is there but could not be enumerated: transient. Keep the last good index, publish nothing,
        // and stay incomplete so the panel holds "indexing…" rather than showing a zeroed chart.
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return BurnSummary(buckets: [], indexedAt: nil, complete: false, fileCount: files.count)
        }
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true,
                  let mtime = values.contentModificationDate, now.timeIntervalSince(mtime) <= Self.fileMaxAge else { continue }
            let path = url.path
            seen.insert(path)
            let size = values.fileSize ?? 0
            var index = files[path] ?? FileBurnIndex()
            if scannedMTimes[path] == mtime, index.bytesScanned == size { continue }
            if size < index.bytesScanned { index = FileBurnIndex() }          // truncated or replaced: start over
            if size > index.bytesScanned { ingest(url, from: index.bytesScanned, size: size, into: &index, cutoff: cutoff) }
            BurnBucketer.prune(&index, keepAfter: cutoff)
            files[path] = index
            scannedMTimes[path] = mtime
            dirty = true
        }
        for path in files.keys where !seen.contains(path) {
            files[path] = nil
            scannedMTimes[path] = nil
            dirty = true
        }
        if dirty { save(now: now, force: lastSavedAt == nil) }
        let records = files.values.flatMap { $0.records.values }
        return BurnSummary(buckets: BurnBucketer.buckets(records: records, count: 48, endingAt: now),
                           indexedAt: now, complete: true, fileCount: files.count)
    }

    /// Restores the persisted index once, on the queue, so launch never waits for a 1.5 MB decode on the main thread.
    private func restoreIfNeeded() {
        guard !restored else { return }
        restored = true
        guard let data = try? Data(contentsOf: storeURL) else { return }
        if let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            files = snapshot.files
        } else {
            burnLog.error("burn index at \(self.storeURL.path) could not be decoded; rebuilding from scratch")
        }
    }

    /// Reads `[start, size)` in 8 MB chunks. `BurnBucketer.ingest` consumes whole lines only, so a line cut by a
    /// chunk boundary is re-read from its start on the next iteration; a partial trailing line waits for the next pass.
    private func ingest(_ url: URL, from start: Int, size: Int, into index: inout FileBurnIndex, cutoff: Date) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        var offset = start
        while offset < size {
            guard (try? handle.seek(toOffset: UInt64(offset))) != nil,
                  let data = try? handle.read(upToCount: Self.chunkBytes), !data.isEmpty else { return }
            let consumed = BurnBucketer.ingest(data, into: &index, keepAfter: cutoff)
            if consumed == 0 { return }
            offset += consumed
        }
    }

    /// Plan 3 §9.3: at most one save per `saveInterval` unless forced (first pass, flush).
    private func save(now: Date, force: Bool) {
        if !force, let last = lastSavedAt, now.timeIntervalSince(last) < Self.saveInterval { return }
        do {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Snapshot(files: files, savedAt: now))
            try data.write(to: storeURL, options: .atomic)
            dirty = false
            lastSavedAt = now
        } catch {
            burnLog.error("burn index not saved: \(String(describing: error))")
        }
    }
}
