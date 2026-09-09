import Foundation

public enum ISO8601 {
    /// Parses ISO 8601 with or without fractional seconds. Fractions beyond milliseconds are truncated.
    public static func parse(_ s: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: normalizeFraction(s)) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }

    /// `ISO8601DateFormatter` accepts at most 3 fractional digits; trim longer fractions.
    static func normalizeFraction(_ s: String) -> String {
        guard let dot = s.firstIndex(of: ".") else { return s }
        let afterDot = s[s.index(after: dot)...]
        guard let end = afterDot.firstIndex(where: { !$0.isNumber }) else { return s }
        let digits = afterDot[..<end]
        if digits.count <= 3 { return s }
        return String(s[...dot]) + digits.prefix(3) + s[end...]
    }
}

public enum ContextWindow {
    public static let small = 200_000
    public static let large = 1_000_000

    /// Spec 2026-09-07 §3.2: 1M for `[1m]` model ids, display names ending in `1M`, and any Fable model
    /// (by id or display name); else 200K.
    public static func defaultSize(modelId: String?, displayName: String?) -> Int {
        if let modelId {
            let lower = modelId.lowercased()
            if lower.contains("[1m]") || lower.contains("fable") { return large }
        }
        if let displayName {
            let upper = displayName.uppercased()
            if upper.hasSuffix("1M") || upper.contains("FABLE") { return large }
        }
        return small
    }

    /// A session cannot hold more than its window, so observed usage above the guess proves the guess wrong.
    public static func reconcile(size: Int, observedTokens: Int) -> Int {
        observedTokens > size ? large : size
    }
}

public struct StatuslineRecord: Sendable, Equatable {
    public let sessionId: String
    public let transcriptPath: String?
    public let cwd: String?
    public let modelId: String?
    public let modelDisplayName: String?
    /// Plan 4 §5.1: `effort.level` — `low`, `medium`, `high`, `xhigh` or `max`; nil when the feed predates the field.
    public let effortLevel: String?
    public let contextWindowSize: Int?
    public let usedPercentage: Double?
    public let totalInputTokens: Int?
    public let totalCostUSD: Double?
    public let rateLimits: Limits?
}

public enum StatuslineParser {
    /// `fetchedAt` stamps the parsed rate limits; pass the feed file's modification date so a stale file cannot
    /// pose as fresher data. Defaults to now for callers that have no file behind the bytes.
    public static func parse(_ data: Data, fetchedAt: Date? = nil) -> StatuslineRecord? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let sessionId = o["session_id"] as? String else { return nil }
        let model = o["model"] as? [String: Any]
        let ctx = o["context_window"] as? [String: Any]
        let cost = o["cost"] as? [String: Any]
        let effort = o["effort"] as? [String: Any]
        return StatuslineRecord(
            sessionId: sessionId,
            transcriptPath: o["transcript_path"] as? String,
            cwd: o["cwd"] as? String,
            modelId: model?["id"] as? String,
            modelDisplayName: model?["display_name"] as? String,
            effortLevel: effort?["level"] as? String,
            contextWindowSize: ctx?["context_window_size"] as? Int,
            usedPercentage: ctx?["used_percentage"] as? Double,
            totalInputTokens: ctx?["total_input_tokens"] as? Int,
            totalCostUSD: cost?["total_cost_usd"] as? Double,
            rateLimits: parseLimits(o["rate_limits"] as? [String: Any], fetchedAt: fetchedAt ?? Date(), source: .feed)
        )
    }

    /// Shared with UsageCacheParser. Two shapes: the documented statusline feed, `{five_hour: {used_percentage,
    /// resets_at: <epoch seconds>}, seven_day: {...}}`, and the `/usage` cache, `{five_hour: {utilization, resets_at:
    /// <ISO 8601>}, ...}`. Other windows (`spend_limit`) are ignored.
    static func parseLimits(_ o: [String: Any]?, fetchedAt: Date?, source: LimitSource) -> Limits? {
        guard let o else { return nil }
        func window(_ key: String) -> LimitWindow? {
            guard let w = o[key] as? [String: Any],
                  let u = (w["utilization"] ?? w["used_percentage"]) as? Double else { return nil }
            let resets: Date?
            switch w["resets_at"] {
            case let iso as String: resets = ISO8601.parse(iso)
            case let epoch as Double: resets = Date(timeIntervalSince1970: epoch)
            default: resets = nil
            }
            return LimitWindow(utilization: Int(u.rounded()), resetsAt: resets)
        }
        let five = window("five_hour")
        let seven = window("seven_day")
        if five == nil && seven == nil { return nil }
        return Limits(fiveHour: five, sevenDay: seven, fetchedAt: fetchedAt, source: source)
    }
}
