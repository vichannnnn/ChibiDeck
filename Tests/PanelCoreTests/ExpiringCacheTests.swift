import Foundation
import Testing
@testable import PanelCore

@Suite struct ExpiringCacheTests {
    static func t(_ s: TimeInterval) -> Date { Date(timeIntervalSince1970: s) }

    @Test func valueLivesForTheTTL() {
        var c = ExpiringCache<String, Int>(ttl: 60)
        c.set(1, for: "a", now: Self.t(0))
        #expect(c.value(for: "a", now: Self.t(59)) == 1)
        #expect(c.value(for: "a", now: Self.t(60)) == nil)
        #expect(c.value(for: "missing", now: Self.t(0)) == nil)
    }

    @Test func setReplacesAndRemoveDrops() {
        var c = ExpiringCache<String, Int>(ttl: 60)
        c.set(1, for: "a", now: Self.t(0))
        c.set(2, for: "a", now: Self.t(30))
        #expect(c.value(for: "a", now: Self.t(80)) == 2)      // the second set restarted the clock
        c.remove("a")
        #expect(c.value(for: "a", now: Self.t(30)) == nil)
        #expect(c.count == 0)
    }

    @Test func sweepDropsOnlyExpiredEntries() {
        var c = ExpiringCache<String, Int>(ttl: 60)
        c.set(1, for: "old", now: Self.t(0))
        c.set(2, for: "new", now: Self.t(50))
        c.sweep(now: Self.t(70))
        #expect(c.count == 1)
        #expect(c.value(for: "new", now: Self.t(70)) == 2)
    }

    @Test func retainKeepsOnlyTheGivenKeys() {
        var c = ExpiringCache<Int, String>(ttl: 3600)
        c.set("x", for: 1, now: Self.t(0))
        c.set("y", for: 2, now: Self.t(0))
        c.set("z", for: 3, now: Self.t(0))
        c.retain([2, 3])
        #expect(c.count == 2)
        #expect(c.value(for: 1, now: Self.t(1)) == nil)
        #expect(c.value(for: 2, now: Self.t(1)) == "y")
    }

    @Test func optionalValuesDistinguishCachedNilFromAbsent() {
        var c = ExpiringCache<String, String?>(ttl: 60)
        c.set(nil, for: "no-branch", now: Self.t(0))
        let hit = c.value(for: "no-branch", now: Self.t(1))
        #expect(hit != nil)              // cached
        #expect(hit! == nil)             // …and the cached value is nil
        #expect(c.value(for: "other", now: Self.t(1)) == nil)
    }
}
