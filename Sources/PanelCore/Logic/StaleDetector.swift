import Foundation

public enum StaleDetector {
    /// Spec 2026-09-23 §4.3: the listing runs every 30 s, so three missed polls (90 s) read as stale.
    public static func isStale(lastSuccess: Date?, now: Date, threshold: TimeInterval = 90) -> Bool {
        guard let lastSuccess else { return true }
        return now.timeIntervalSince(lastSuccess) > threshold
    }
}
