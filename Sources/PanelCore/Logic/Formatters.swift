import Foundation

public enum PanelFormat {
    public static func hhmm(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    public static func elapsed(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
        return d > 0 ? "\(d)d \(h)h" : "\(h)h \(m)m"
    }

    public static func reset(_ date: Date?, now: Date, calendar: Calendar = .current) -> String {
        guard let date else { return "—" }
        if date.timeIntervalSince(now) < 24 * 3600 { return hhmm(date, calendar: calendar) }
        var cal = calendar
        cal.locale = Locale(identifier: "en_US_POSIX")
        let weekday = cal.shortWeekdaySymbols[cal.component(.weekday, from: date) - 1]
        return "\(weekday) \(hhmm(date, calendar: calendar))"
    }

    public static func shortModel(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "?" }
        let lower = name.lowercased()
        for family in ["fable", "mythos", "opus", "sonnet", "haiku"] where lower.contains(family) {
            return family.prefix(1).uppercased() + family.dropFirst()
        }
        return String(name.split(separator: " ").first ?? Substring(name))
    }

    /// Plan 4 §5.1: `Fable 5.1` from a display name (`Fable 5.1`, `Opus 5 1M`) or a model id (`claude-fable-5-1[1m]`,
    /// `claude-haiku-4-5-20251001`). A `[…]` suffix is dropped; the version is the run of number groups after the
    /// family, joined with `.`; an 8-digit group is a date, not a version; unknown families come back trimmed; `?` when empty.
    public static func modelLabel(_ name: String?) -> String {
        guard var s = name?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return "?" }
        if let bracket = s.firstIndex(of: "[") { s = String(s[..<bracket]).trimmingCharacters(in: .whitespaces) }
        let lower = s.lowercased()
        guard let family = ["fable", "mythos", "opus", "sonnet", "haiku"].first(where: { lower.contains($0) }),
              let range = lower.range(of: family) else { return s }
        var groups: [String] = []
        for part in lower[range.upperBound...].split(whereSeparator: { $0 == "-" || $0 == "." || $0 == " " }) {
            guard part.allSatisfy(\.isNumber), part.count < 8 else { break }
            groups.append(String(part))
        }
        let title = family.prefix(1).uppercased() + family.dropFirst()
        return groups.isEmpty ? title : title + " " + groups.joined(separator: ".")
    }

    /// Plan 4 §5.2: `375k / 1M`; `—` when either number is unknown.
    public static func contextLabel(used: Int?, size: Int?) -> String {
        guard let used, let size, size > 0 else { return "—" }
        return "\(compactTokens(used)) / \(compactTokens(size))"
    }

    /// Plan 4 §4.4: `12am`, `4am`, `12pm`, `4pm` for the chart's X axis.
    public static func hourLabel(_ date: Date, calendar: Calendar = .current) -> String {
        let h = calendar.component(.hour, from: date)
        let twelve = h % 12 == 0 ? 12 : h % 12
        return "\(twelve)\(h < 12 ? "am" : "pm")"
    }

    public static func homeRelative(_ path: String, home: String) -> String {
        path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    public static func cost(_ usd: Double?) -> String {
        guard let usd else { return "—" }
        return String(format: "$%.2f", usd)
    }

    /// `642`, `1.6k`, `155k`, `1M`, `19.6M`, `168M`, `1.1B` (spec §2.1; one decimal under 10k and above 1M when it is
    /// not zero). From 100M the decimal is dropped and above 1B the `B` tier takes over, so no label passes five
    /// characters — the chart's 64 pt gutter and the TODAY columns are sized for that (§4.3).
    public static func compactTokens(_ n: Int) -> String {
        if n >= 1_000_000_000 { return oneDecimal(Double(n) / 1_000_000_000) + "B" }
        if n >= 100_000_000 { return "\(n / 1_000_000)M" }
        if n >= 1_000_000 { return oneDecimal(Double(n) / 1_000_000) + "M" }
        if n >= 10_000 { return "\(n / 1000)k" }
        if n >= 1_000 { return oneDecimal(Double(n) / 1000) + "k" }
        return "\(n)"
    }

    private static func oneDecimal(_ v: Double) -> String {
        let s = String(format: "%.1f", v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }

    /// Spec 2026-09-07 (Plan 4) §4.2: `resets in 1:38:22` under 24 h, counting down to the second and never
    /// negative; else `resets Tue 17:00`.
    public static func resetsIn(_ date: Date?, now: Date, calendar: Calendar = .current) -> String {
        guard let date else { return "resets —" }
        let seconds = date.timeIntervalSince(now)
        if seconds < 24 * 3600 {
            let s = max(0, Int(seconds.rounded(.down)))
            return String(format: "resets in %d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return "resets \(reset(date, now: now, calendar: calendar))"
    }

    /// `~full by 09:10` today, `~full Tue 09:10` later; nil without a forecast.
    public static func fullBy(_ date: Date?, now: Date, calendar: Calendar = .current) -> String? {
        guard let date else { return nil }
        return date.timeIntervalSince(now) < 24 * 3600
            ? "~full by \(hhmm(date, calendar: calendar))"
            : "~full \(reset(date, now: now, calendar: calendar))"
    }

    /// Card elapsed (spec §2.4 row 1): `14m`, `1h 12m`, `2d 3h`, `56d` from a week on.
    public static func elapsedShort(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
        if d >= 7 { return "\(d)d" }
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
