import Foundation

public struct LimitSample: Sendable, Equatable {
    public let at: Date
    public let percent: Int

    public init(at: Date, percent: Int) {
        self.at = at
        self.percent = percent
    }
}

/// Spec 2026-09-07 §3.3: the last twelve `(fetchedAt, percent)` samples per limit row, in memory only.
public struct LimitSampleStore: Sendable, Equatable {
    public static let capacity = 12
    /// Plan 3 §8.5: the statusline feed writes every few seconds, so samples are thinned to at most one per minute.
    public static let minimumSpacing: TimeInterval = 60
    private var byRow: [String: [LimitSample]] = [:]

    public init() {}

    /// Records one sample per row, stamped with the row's own fetch date (Plan 3 §8.5) or the set's. A sample is
    /// ignored when neither date exists, and samples are thinned to one per minute: a date less than
    /// `minimumSpacing` after the row's newest sample is dropped (the same cache read twice, an older source, or
    /// the statusline feed's every-few-seconds writes), so the twelve slots span twelve minutes, not one.
    public mutating func record(_ limits: Limits) {
        for row in limits.rows {
            guard let at = row.fetchedAt ?? limits.fetchedAt else { continue }
            var list = byRow[row.id] ?? []
            if let last = list.last, at.timeIntervalSince(last.at) < Self.minimumSpacing { continue }
            list.append(LimitSample(at: at, percent: row.percent))
            if list.count > Self.capacity { list.removeFirst(list.count - Self.capacity) }
            byRow[row.id] = list
        }
    }

    public func samples(for rowId: String) -> [LimitSample] { byRow[rowId] ?? [] }
}

public enum LimitForecast {
    /// Only samples from the last hour take part.
    public static let window: TimeInterval = 60 * 60
    /// The oldest and newest samples used must be at least this far apart.
    public static let minimumSpan: TimeInterval = 5 * 60

    /// Spec 2026-09-07 §3.3. Nil unless the recent run rises, spans ≥ 5 min, and reaches 100 % before `resetsAt`.
    public static func fullBy(samples: [LimitSample], now: Date, resetsAt: Date?) -> Date? {
        let recent = samples.filter { $0.at <= now && now.timeIntervalSince($0.at) <= window }
        // A drop inside the window means the limit reset; only the run after the last drop is a trend.
        var run = recent
        if let lastDrop = recent.indices.dropFirst().last(where: { recent[$0].percent < recent[$0 - 1].percent }) {
            run = Array(recent[lastDrop...])
        }
        guard let oldest = run.first, let newest = run.last,
              newest.at.timeIntervalSince(oldest.at) >= minimumSpan,
              newest.percent > oldest.percent else { return nil }
        let slope = Double(newest.percent - oldest.percent) / newest.at.timeIntervalSince(oldest.at)   // percent per second
        let projected = newest.at.addingTimeInterval(Double(100 - newest.percent) / slope)
        if let resetsAt, projected >= resetsAt { return nil }
        return projected
    }

    /// One forecast per row that has one, keyed by row id.
    public static func forecasts(limits: Limits, store: LimitSampleStore, now: Date) -> [String: Date] {
        var out: [String: Date] = [:]
        for row in limits.rows {
            if let date = fullBy(samples: store.samples(for: row.id), now: now, resetsAt: row.resetsAt) { out[row.id] = date }
        }
        return out
    }
}
