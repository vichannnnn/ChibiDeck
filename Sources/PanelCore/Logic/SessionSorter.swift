import Foundation

public enum SessionSorter {
    public static func sort(_ sessions: [Session]) -> [Session] {
        sessions.sorted { a, b in
            if a.status.sortRank != b.status.sortRank { return a.status.sortRank < b.status.sortRank }
            let ta = a.statusUpdatedAt ?? .distantPast, tb = b.statusUpdatedAt ?? .distantPast
            if ta != tb { return ta > tb }
            return a.name < b.name
        }
    }

    public static func cap(_ sorted: [Session], limit: Int = 8) -> (shown: [Session], hidden: Int) {
        (Array(sorted.prefix(limit)), max(0, sorted.count - limit))
    }
}
