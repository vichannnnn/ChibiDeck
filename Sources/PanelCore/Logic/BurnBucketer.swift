import Foundation

public enum BurnBucketer {
    /// Parses one transcript line. Nil unless it is an assistant line carrying a `timestamp`, `message.id` and `message.usage`.
    /// The byte-level `"usage"` check runs before any JSON work so the indexer skips most lines cheaply.
    public static func record(fromLine line: Substring) -> UsageRecord? {
        guard line.contains("\"usage\"") else { return nil }
        guard let data = line.data(using: .utf8),
              let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              (o["type"] as? String) == "assistant",
              let timestamp = (o["timestamp"] as? String).flatMap(ISO8601.parse),
              let message = o["message"] as? [String: Any],
              let id = message["id"] as? String, !id.isEmpty,
              let usage = message["usage"] as? [String: Any] else { return nil }
        return UsageRecord(
            messageId: id,
            timestamp: timestamp,
            input: (usage["input_tokens"] as? Int) ?? 0,
            cacheWrite: (usage["cache_creation_input_tokens"] as? Int) ?? 0,
            cacheRead: (usage["cache_read_input_tokens"] as? Int) ?? 0,
            output: (usage["output_tokens"] as? Int) ?? 0
        )
    }

    /// Feeds bytes appended to a transcript into its index. Only complete lines (ending in `\n`) are consumed —
    /// a trailing partial line stays unread until the next pass. Records older than `cutoff` are not kept.
    /// Returns the number of bytes consumed; `index.bytesScanned` advances by the same amount.
    @discardableResult
    public static func ingest(_ data: Data, into index: inout FileBurnIndex, keepAfter cutoff: Date) -> Int {
        guard let lastNewline = data.lastIndex(of: 0x0A) else { return 0 }
        let complete = data[data.startIndex...lastNewline]
        let text = String(decoding: complete, as: UTF8.self)
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let record = record(fromLine: line), record.timestamp >= cutoff else { continue }
            index.records[record.messageId] = record
        }
        index.bytesScanned += complete.count
        return complete.count
    }

    public static func prune(_ index: inout FileBurnIndex, keepAfter cutoff: Date) {
        index.records = index.records.filter { $0.value.timestamp >= cutoff }
    }

    public static func hourStart(_ date: Date, calendar: Calendar) -> Date {
        let c = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return calendar.date(from: c) ?? date
    }

    /// `count` hour-aligned buckets, oldest first, ending at the hour containing `end`. Records outside them are ignored.
    public static func buckets(records: [UsageRecord], count: Int, endingAt end: Date, calendar: Calendar = .current) -> [HourBucket] {
        let last = hourStart(end, calendar: calendar)
        let starts: [Date] = (0..<count).reversed().compactMap { calendar.date(byAdding: .hour, value: -$0, to: last) }
        var byStart: [Date: HourBucket] = [:]
        for start in starts { byStart[start] = HourBucket(hourStart: start) }
        for record in records {
            let start = hourStart(record.timestamp, calendar: calendar)
            guard var bucket = byStart[start] else { continue }
            bucket.burn += record.burn
            bucket.output += record.output
            bucket.input += record.input
            bucket.cacheRead += record.cacheRead
            bucket.messages += 1
            byStart[start] = bucket
        }
        return starts.compactMap { byStart[$0] }
    }

    /// Spec 2026-09-07 §2.3: the 24 hours ending at the hour containing `now`; hours the index has no bucket for are empty.
    public static func chart(from summary: BurnSummary, now: Date, calendar: Calendar = .current) -> BurnChart {
        let byStart = Dictionary(summary.buckets.map { ($0.hourStart, $0) }, uniquingKeysWith: { first, _ in first })
        let last = hourStart(now, calendar: calendar)
        let bars: [HourBucket] = (0..<24).reversed().compactMap { back in
            guard let start = calendar.date(byAdding: .hour, value: -back, to: last) else { return nil }
            return byStart[start] ?? HourBucket(hourStart: start)
        }
        let burns = bars.map(\.burn)
        let peak = burns.max() ?? 0
        let mean = bars.isEmpty ? 0 : Double(burns.reduce(0, +)) / Double(bars.count)
        return BurnChart(bars: bars, peak: peak, mean: mean)
    }

    /// Spec 2026-09-07 §2.3 TODAY: the sum of buckets from local midnight up to `now`.
    public static func today(from summary: BurnSummary, now: Date, calendar: Calendar = .current) -> TodayTotals {
        let start = calendar.startOfDay(for: now)
        let todays = summary.buckets.filter { $0.hourStart >= start && $0.hourStart <= now }
        return TodayTotals(
            output: todays.map(\.output).reduce(0, +),
            input: todays.map(\.input).reduce(0, +),
            cacheRead: todays.map(\.cacheRead).reduce(0, +),
            messages: todays.map(\.messages).reduce(0, +)
        )
    }
}
