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
}
