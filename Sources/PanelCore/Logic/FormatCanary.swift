import Foundation

/// Spec 2026-09-23 §9.1: the fields the panel reads from Claude Code's files, and what stops working without each.
public enum FormatField: String, Sendable, CaseIterable {
    case sessionStatusUpdatedAt, feedContext, feedModel, feedCost, feedRateLimits
    case transcriptUsage, transcriptTurnEnd, transcriptTitle
    case listingShape, usageCacheShape, statsCacheShape

    /// The menu line: where the field is missing, then what it breaks.
    public var warning: String {
        switch self {
        case .sessionStatusUpdatedAt: "session files have no statusUpdatedAt — card order"
        case .feedContext: "feed has no context_window — context bars"
        case .feedModel: "feed has no model — model chips"
        case .feedCost: "feed has no cost — today's cost"
        case .feedRateLimits: "feed has no rate_limits — limit bars"
        case .transcriptUsage: "transcripts have no usage — context estimate, burn chart"
        case .transcriptTurnEnd: "transcripts have no turn_duration — Handoff"
        case .transcriptTitle: "transcripts have no ai-title — card titles"
        case .listingShape: "claude agents --json is not a list — sessions"
        case .usageCacheShape: "~/.claude.json usage cache not recognised — limit rows"
        case .statsCacheShape: "stats-cache.json not recognised — TODAY"
        }
    }
}

/// Spec 2026-09-23 §9.2. A field is flagged when its oldest absent observation since the last present one is at least
/// `window` old and there have been at least two absent observations since; the next present observation clears it.
/// A field never observed is never flagged. An unknown session status is flagged from the moment it is seen until
/// `window` after it was last seen.
public struct FormatCanary: Sendable {
    public static let window: TimeInterval = 10 * 60

    private struct Absence: Sendable {
        var since: Date
        var count: Int
    }
    private var absences: [FormatField: Absence] = [:]
    private var unknownStatuses: [String: Date] = [:]

    public init() {}

    public mutating func observe(_ field: FormatField, present: Bool, at time: Date) {
        if present { absences[field] = nil; return }
        if var a = absences[field] {
            a.count += 1
            absences[field] = a
        } else {
            absences[field] = Absence(since: time, count: 1)
        }
    }

    public mutating func observeUnknownStatus(_ raw: String, at time: Date) {
        unknownStatuses[raw] = time
        unknownStatuses = unknownStatuses.filter { time.timeIntervalSince($0.value) < Self.window }
    }

    /// Unknown statuses first (alphabetical), then fields in declaration order.
    public func warnings(at now: Date) -> [String] {
        let statuses = unknownStatuses.filter { now.timeIntervalSince($0.value) < Self.window }.keys.sorted()
            .map { "session status \u{201C}\($0)\u{201D} is new to the panel — card status" }
        let fields = FormatField.allCases.filter { field in
            guard let a = absences[field] else { return false }
            return a.count >= 2 && now.timeIntervalSince(a.since) >= Self.window
        }
        return statuses + fields.map(\.warning)
    }
}
