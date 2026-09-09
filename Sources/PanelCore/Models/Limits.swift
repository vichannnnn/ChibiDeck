import Foundation

public struct LimitWindow: Sendable, Equatable {
    /// Percent used, 0…100.
    public let utilization: Int
    public let resetsAt: Date?

    public init(utilization: Int, resetsAt: Date?) {
        self.utilization = min(100, max(0, utilization))
        self.resetsAt = resetsAt
    }
}

/// One limit as the panel shows it (spec 2026-09-07 §3.3). `id` is `session`, `weekly`, or `weekly:<model>`.
public struct LimitRow: Sendable, Equatable, Identifiable {
    public static let sessionId = "session"
    public static let weeklyId = "weekly"

    public let id: String
    public let title: String
    /// Percent used, 0…100.
    public let percent: Int
    public let resetsAt: Date?
    /// The model display name for a scoped row (`Fable`), nil for the two account-wide rows.
    public let scopeName: String?
    /// When this row's source was fetched (Plan 3 §8.5). Nil until `Limits.merging` stamps it with its source's date.
    public let fetchedAt: Date?

    public init(id: String, title: String, percent: Int, resetsAt: Date?, scopeName: String? = nil, fetchedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.percent = min(100, max(0, percent))
        self.resetsAt = resetsAt
        self.scopeName = scopeName
        self.fetchedAt = fetchedAt
    }

    public var isScoped: Bool { id != Self.sessionId && id != Self.weeklyId }

    /// The same row carrying `date` when it has no fetch date of its own.
    func stamped(with date: Date?) -> LimitRow {
        guard fetchedAt == nil, let date else { return self }
        return LimitRow(id: id, title: title, percent: percent, resetsAt: resetsAt, scopeName: scopeName, fetchedAt: date)
    }
}

/// Where a set of limits came from: Claude Code's `/usage` cache in `~/.claude.json`, or the statusline feed that
/// Claude Code refreshes from the rate-limit headers of every API response.
public enum LimitSource: String, Sendable, Equatable {
    case cache
    case feed
}

public struct Limits: Sendable, Equatable {
    /// Plan 3 §8.5: a scoped row that Claude Code stopped reporting leaves the display after this long.
    public static let scopedRowMaxAge: TimeInterval = 6 * 3600

    public let rows: [LimitRow]
    public let fetchedAt: Date?
    /// The source of the newest rows in this set; nil for `.empty` and for sets built without one.
    public let source: LimitSource?

    public init(rows: [LimitRow], fetchedAt: Date?, source: LimitSource? = nil) {
        self.rows = rows
        self.fetchedAt = fetchedAt
        self.source = source
    }

    /// Legacy shape used by the statusline feed and older caches: at most the two account-wide rows.
    public init(fiveHour: LimitWindow?, sevenDay: LimitWindow?, fetchedAt: Date?, source: LimitSource? = nil) {
        var rows: [LimitRow] = []
        if let f = fiveHour { rows.append(LimitRow(id: LimitRow.sessionId, title: "5-HOUR", percent: f.utilization, resetsAt: f.resetsAt)) }
        if let s = sevenDay { rows.append(LimitRow(id: LimitRow.weeklyId, title: "WEEKLY", percent: s.utilization, resetsAt: s.resetsAt)) }
        self.init(rows: rows, fetchedAt: fetchedAt, source: source)
    }

    public static let empty = Limits(rows: [], fetchedAt: nil)

    public func row(_ id: String) -> LimitRow? { rows.first { $0.id == id } }

    public var fiveHour: LimitWindow? { row(LimitRow.sessionId).map { LimitWindow(utilization: $0.percent, resetsAt: $0.resetsAt) } }
    public var sevenDay: LimitWindow? { row(LimitRow.weeklyId).map { LimitWindow(utilization: $0.percent, resetsAt: $0.resetsAt) } }

    /// Plan 3 §8.5: per row id, the row fetched later wins (ties go to `other`); rows present on one side only
    /// survive; the result's `fetchedAt` is the later of the two and its `source` is that set's. Rows are stamped
    /// with their source's fetch date so a scoped row from the cache keeps its own age through later feed merges.
    public func merging(_ other: Limits) -> Limits {
        var byId: [String: LimitRow] = [:]
        var order: [String] = []
        for row in rows.map({ $0.stamped(with: fetchedAt) }) + other.rows.map({ $0.stamped(with: other.fetchedAt) }) {
            if let existing = byId[row.id] {
                if (row.fetchedAt ?? .distantPast) >= (existing.fetchedAt ?? .distantPast) { byId[row.id] = row }
            } else {
                byId[row.id] = row
                order.append(row.id)
            }
        }
        let otherIsNewer = (other.fetchedAt ?? .distantPast) >= (fetchedAt ?? .distantPast)
        return Limits(rows: order.compactMap { byId[$0] }, fetchedAt: [fetchedAt, other.fetchedAt].compactMap { $0 }.max(),
                      source: otherIsNewer ? (other.source ?? source) : source)
    }

    /// Spec §2.3 order: session, weekly, then scoped rows by percent descending (ties by id); at most `max` rows.
    /// With `now`, a scoped row whose own fetch date is older than `scopedRowMaxAge` is omitted (Plan 3 §8.5).
    public func displayRows(max: Int = 4, now: Date? = nil) -> [LimitRow] {
        var out: [LimitRow] = []
        if let s = row(LimitRow.sessionId) { out.append(s) }
        if let w = row(LimitRow.weeklyId) { out.append(w) }
        let scoped = rows.filter { row in
            guard row.isScoped else { return false }
            guard let now, let at = row.fetchedAt else { return true }
            return now.timeIntervalSince(at) <= Self.scopedRowMaxAge
        }.sorted { a, b in
            a.percent != b.percent ? a.percent > b.percent : a.id < b.id
        }
        out.append(contentsOf: scoped)
        return Array(out.prefix(max))
    }

    /// Spec 2026-09-06 §5.3: data older than 30 minutes is shown with a `~`.
    public func isOld(at now: Date) -> Bool {
        guard let fetchedAt else { return true }
        return now.timeIntervalSince(fetchedAt) > 30 * 60
    }
}
