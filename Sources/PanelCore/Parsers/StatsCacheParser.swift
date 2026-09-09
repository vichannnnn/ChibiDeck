import Foundation

public enum StatsCacheParser {
    public static func parse(_ data: Data) -> [DailyActivity] {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let days = o["dailyActivity"] as? [[String: Any]] else { return [] }
        return days.compactMap { d in
            guard let date = d["date"] as? String else { return nil }
            return DailyActivity(
                date: date,
                messageCount: (d["messageCount"] as? Int) ?? 0,
                sessionCount: (d["sessionCount"] as? Int) ?? 0,
                toolCallCount: (d["toolCallCount"] as? Int) ?? 0
            )
        }
    }

    public static func dateKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func entry(for date: Date, in activity: [DailyActivity], calendar: Calendar = .current) -> DailyActivity? {
        let key = dateKey(date, calendar: calendar)
        return activity.first { $0.date == key }
    }

    /// Seven entries, oldest first, ending on `endingOn`; missing days are nil.
    public static func lastSevenDays(endingOn end: Date, in activity: [DailyActivity], calendar: Calendar = .current) -> [DailyActivity?] {
        (0..<7).reversed().map { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: end) else { return nil }
            return entry(for: day, in: activity, calendar: calendar)
        }
    }
}
