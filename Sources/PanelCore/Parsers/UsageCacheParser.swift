import Foundation

public enum UsageCacheParser {
    /// Reads `cachedUsageUtilization` from the whole `~/.claude.json` document. Prefers the `limits[]` array
    /// (spec 2026-09-07 §3.3), which Claude Code has written both beside `utilization` and, since 2026-09-07,
    /// inside it; falls back to the legacy `utilization.five_hour` / `seven_day` buckets.
    public static func parse(_ data: Data) -> Limits? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let cache = o["cachedUsageUtilization"] as? [String: Any] else { return nil }
        let fetchedAt = (cache["fetchedAtMs"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
        let utilization = cache["utilization"] as? [String: Any]
        if let entries = (cache["limits"] ?? utilization?["limits"]) as? [[String: Any]] {
            let rows = entries.compactMap(row(from:))
            if !rows.isEmpty { return Limits(rows: rows, fetchedAt: fetchedAt, source: .cache) }
        }
        return StatuslineParser.parseLimits(utilization, fetchedAt: fetchedAt, source: .cache)
            ?? Limits(rows: [], fetchedAt: fetchedAt, source: .cache)
    }

    /// `session` → 5-HOUR, `weekly_all` → WEEKLY, `weekly_scoped` → `<MODEL> WEEKLY`; other kinds and scoped
    /// entries without a model display name are ignored.
    static func row(from e: [String: Any]) -> LimitRow? {
        guard let kind = e["kind"] as? String else { return nil }
        let percent = Int(((e["percent"] as? Double) ?? 0).rounded())
        let resets = (e["resets_at"] as? String).flatMap(ISO8601.parse)
        switch kind {
        case "session":
            return LimitRow(id: LimitRow.sessionId, title: "5-HOUR", percent: percent, resetsAt: resets)
        case "weekly_all":
            return LimitRow(id: LimitRow.weeklyId, title: "WEEKLY", percent: percent, resetsAt: resets)
        case "weekly_scoped":
            guard let scope = e["scope"] as? [String: Any], let model = scope["model"] as? [String: Any],
                  let name = model["display_name"] as? String, !name.isEmpty else { return nil }
            return LimitRow(id: "weekly:\(name.lowercased())", title: "\(name.uppercased()) WEEKLY",
                            percent: percent, resetsAt: resets, scopeName: name)
        default:
            return nil
        }
    }
}
