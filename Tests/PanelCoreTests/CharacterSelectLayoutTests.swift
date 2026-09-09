import Foundation
import Testing
@testable import PanelCore

@Suite struct CharacterSelectLayoutTests {
    @Test func nineCharactersFitAtThreeTimes() {
        let l = CharacterSelectLayout(count: 9)
        #expect(l.scale == 3)
        #expect(l.tileSize.width == 228 && l.tileSize.height == 285)
        #expect(l.frames.count == 9)
        #expect(l.frames[0].origin.x == 190 && l.frames[0].origin.y == 217)
        // PanelCore is Foundation only, so the rect arithmetic below stays on origin and size (no CoreGraphics helpers).
        for (a, b) in zip(l.frames, l.frames.dropFirst()) {
            let gap = b.origin.x - (a.origin.x + a.size.width)
            let equal = gap == CharacterSelectLayout.gap      // compared outside #expect: the macro reports 16.0 == 16.0 as failed for CGFloat here
            #expect(equal)
            #expect(a.origin.y == b.origin.y)
        }
        for f in l.frames {
            #expect(f.origin.x >= 0 && f.origin.y >= 0)
            #expect(f.origin.x + f.size.width <= CharacterSelectLayout.canvas.width)
            #expect(f.origin.y + f.size.height <= CharacterSelectLayout.canvas.height)
        }
        let last = l.frames[8]
        let left = l.frames[0].origin.x, right = CharacterSelectLayout.canvas.width - (last.origin.x + last.size.width)
        #expect(abs(left - right) <= 1)
    }

    @Test func scaleDropsAsTheRosterGrows() {
        #expect(CharacterSelectLayout.scale(for: 1) == 3)
        #expect(CharacterSelectLayout.scale(for: 10) == 3)
        #expect(CharacterSelectLayout.scale(for: 11) == 2)
        #expect(CharacterSelectLayout.scale(for: 14) == 2)
        #expect(CharacterSelectLayout.scale(for: 15) == 1)
        #expect(CharacterSelectLayout.scale(for: 40) == 1)     // never below 1; the row overflows, out of scope
    }

    @Test func oneCharacterIsCentred() {
        let l = CharacterSelectLayout(count: 1)
        #expect(l.frames.count == 1)
        #expect(l.frames[0].origin.x == 1166)
        #expect(l.frames[0].origin.y == 217)
    }

    @Test func zeroCharactersHaveNoFrames() {
        #expect(CharacterSelectLayout(count: 0).frames.isEmpty)
    }
}
