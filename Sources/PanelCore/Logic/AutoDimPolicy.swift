import Foundation

public enum AutoDimPolicy {
    static func lastActivity(lastTouch: Date?, lastStateChange: Date?, now: Date) -> Date {
        [lastTouch, lastStateChange].compactMap { $0 }.max() ?? now
    }

    public static func shouldDim(enabled: Bool, lastTouch: Date?, lastStateChange: Date?, now: Date, quietMinutes: Int) -> Bool {
        guard enabled else { return false }
        let last = lastActivity(lastTouch: lastTouch, lastStateChange: lastStateChange, now: now)
        return now.timeIntervalSince(last) > Double(quietMinutes) * 60
    }

    public static func nextCheck(lastTouch: Date?, lastStateChange: Date?, now: Date, quietMinutes: Int) -> TimeInterval {
        let last = lastActivity(lastTouch: lastTouch, lastStateChange: lastStateChange, now: now)
        let remaining = Double(quietMinutes) * 60 - now.timeIntervalSince(last)
        return max(1, remaining)
    }
}
