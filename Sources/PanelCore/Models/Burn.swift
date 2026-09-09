import Foundation

/// One assistant message's usage, counted once per `message.id` (spec 2026-09-07 §3.4: Claude Code writes an
/// assistant turn as several lines that share one id and repeat the same usage).
public struct UsageRecord: Sendable, Equatable, Codable {
    public let messageId: String
    public let timestamp: Date
    public let input: Int
    public let cacheWrite: Int
    public let cacheRead: Int
    public let output: Int

    public init(messageId: String, timestamp: Date, input: Int, cacheWrite: Int, cacheRead: Int, output: Int) {
        self.messageId = messageId
        self.timestamp = timestamp
        self.input = input
        self.cacheWrite = cacheWrite
        self.cacheRead = cacheRead
        self.output = output
    }

    /// Tokens paid at full or cache-write rate. Cache reads are not burn.
    public var burn: Int { input + cacheWrite + output }
}

/// The incremental index of one transcript file: how many bytes were consumed and the records found so far.
public struct FileBurnIndex: Sendable, Equatable, Codable {
    public var bytesScanned: Int
    public var records: [String: UsageRecord]

    public init(bytesScanned: Int = 0, records: [String: UsageRecord] = [:]) {
        self.bytesScanned = bytesScanned
        self.records = records
    }
}

/// Totals for one local clock hour.
public struct HourBucket: Sendable, Equatable, Identifiable {
    public var id: Date { hourStart }
    public let hourStart: Date
    public var burn: Int
    public var output: Int
    public var input: Int
    public var cacheRead: Int
    public var messages: Int

    public init(hourStart: Date, burn: Int = 0, output: Int = 0, input: Int = 0, cacheRead: Int = 0, messages: Int = 0) {
        self.hourStart = hourStart
        self.burn = burn
        self.output = output
        self.input = input
        self.cacheRead = cacheRead
        self.messages = messages
    }

    public var isEmpty: Bool { messages == 0 }
}

/// What the indexer publishes: absolute-hour buckets (oldest first), when it ran, whether a full pass has completed,
/// and how many transcript files were in scope (0 with `complete` means "no transcripts").
public struct BurnSummary: Sendable, Equatable {
    public let buckets: [HourBucket]
    public let indexedAt: Date?
    public let complete: Bool
    public let fileCount: Int

    public init(buckets: [HourBucket], indexedAt: Date?, complete: Bool, fileCount: Int) {
        self.buckets = buckets
        self.indexedAt = indexedAt
        self.complete = complete
        self.fileCount = fileCount
    }

    public static let indexing = BurnSummary(buckets: [], indexedAt: nil, complete: false, fileCount: 0)

    /// Plan 3 §9.4: the chart keeps the last complete pass through a failed one; after this long that is a cue.
    public static let staleAfter: TimeInterval = 5 * 60

    public func isStale(at now: Date, maxAge: TimeInterval = staleAfter) -> Bool {
        guard let indexedAt else { return true }
        return now.timeIntervalSince(indexedAt) > maxAge
    }
}

/// Spec 2026-09-07 §2.3: 24 bars ending at the current hour, the tallest bar, and the mean.
public struct BurnChart: Sendable, Equatable {
    public let bars: [HourBucket]
    public let peak: Int
    public let mean: Double

    public init(bars: [HourBucket], peak: Int, mean: Double) {
        self.bars = bars
        self.peak = peak
        self.mean = mean
    }
}

/// Spec 2026-09-07 §2.3 TODAY block.
public struct TodayTotals: Sendable, Equatable {
    public let output: Int
    public let input: Int
    public let cacheRead: Int
    public let messages: Int

    public init(output: Int, input: Int, cacheRead: Int, messages: Int) {
        self.output = output
        self.input = input
        self.cacheRead = cacheRead
        self.messages = messages
    }
}
