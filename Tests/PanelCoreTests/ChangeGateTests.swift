import Foundation
import Testing
@testable import PanelCore

@Suite struct ChangeGateTests {
    static let a = FileStamp(size: 100, modified: Date(timeIntervalSince1970: 1_790_000_000.25))

    @Test func aNewPathIsRead() {
        #expect(ChangeGate().shouldRead("/t", stamp: Self.a))
    }

    @Test func anUnchangedStampIsSkippedAndAMovedOneIsRead() {
        var g = ChangeGate()
        g.markRead("/t", stamp: Self.a)
        #expect(!g.shouldRead("/t", stamp: Self.a))
        #expect(g.shouldRead("/t", stamp: FileStamp(size: 101, modified: Self.a.modified)))
        #expect(g.shouldRead("/t", stamp: FileStamp(size: 100, modified: Self.a.modified.addingTimeInterval(0.001))))   // rewritten, same size
    }

    @Test func anUnreadableStampIsAlwaysRead() {
        var g = ChangeGate()
        g.markRead("/t", stamp: Self.a)
        #expect(g.shouldRead("/t", stamp: nil))
        g.markRead("/t", stamp: nil)
        #expect(g.shouldRead("/t", stamp: Self.a))
    }

    @Test func retainDropsPathsThatLeft() {
        var g = ChangeGate()
        g.markRead("/a", stamp: Self.a)
        g.markRead("/b", stamp: Self.a)
        g.retain(["/a"])
        #expect(g.count == 1 && g.shouldRead("/b", stamp: Self.a) && !g.shouldRead("/a", stamp: Self.a))
    }
}
