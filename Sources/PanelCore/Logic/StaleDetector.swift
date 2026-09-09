import Foundation

public enum StaleDetector {
    public static func isStale(lastSuccess: Date?, now: Date, threshold: TimeInterval = 30) -> Bool {
        guard let lastSuccess else { return true }
        return now.timeIntervalSince(lastSuccess) > threshold
    }
}
