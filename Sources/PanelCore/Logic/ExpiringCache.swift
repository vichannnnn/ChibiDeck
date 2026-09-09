import Foundation

/// Spec 2026-09-07 (Plan 3) §9.2: the one keyed, time-limited cache. An entry expires `ttl` seconds after it was
/// set; `sweep` drops expired entries and `retain` drops everything outside a live key set, so no cache grows
/// without bound. `Value` may itself be optional: `value(for:)` then returns `.some(nil)` for a cached nil and
/// `nil` for an absent or expired entry.
public struct ExpiringCache<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    private struct Entry: Sendable {
        let value: Value
        let setAt: Date
    }

    public let ttl: TimeInterval
    private var entries: [Key: Entry] = [:]

    public init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    public func value(for key: Key, now: Date) -> Value? {
        guard let entry = entries[key], now.timeIntervalSince(entry.setAt) < ttl else { return nil }
        return entry.value
    }

    public mutating func set(_ value: Value, for key: Key, now: Date) {
        entries[key] = Entry(value: value, setAt: now)
    }

    public mutating func remove(_ key: Key) {
        entries[key] = nil
    }

    public mutating func sweep(now: Date) {
        entries = entries.filter { now.timeIntervalSince($0.value.setAt) < ttl }
    }

    public mutating func retain(_ keys: Set<Key>) {
        entries = entries.filter { keys.contains($0.key) }
    }

    public var count: Int { entries.count }
}
