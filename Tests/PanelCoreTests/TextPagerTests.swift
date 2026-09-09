import Foundation
import Testing
@testable import PanelCore

@Suite struct TextPagerTests {
    @Test func wrapsAtWords() {
        #expect(TextPager.lines("the quick brown fox jumps", columns: 10) == ["the quick", "brown fox", "jumps"])
        #expect(TextPager.lines("exactly10c fits", columns: 10) == ["exactly10c", "fits"])
    }

    @Test func splitsAWordLongerThanALine() {
        #expect(TextPager.lines("abcdefghij", columns: 4) == ["abcd", "efgh", "ij"])
        #expect(TextPager.lines("abcdefgh", columns: 4) == ["abcd", "efgh"])                 // no blank line after an even split
        #expect(TextPager.lines("go abcdefghij on", columns: 4) == ["go", "abcd", "efgh", "ij", "on"])
    }

    @Test func keepsExplicitNewlines() {
        #expect(TextPager.lines("first\nsecond line\n", columns: 20) == ["first", "second line", ""])
    }

    @Test func pagesGroupRows() {
        let text = "one two three four five six seven eight"
        let pages = TextPager.pages(text, columns: 9, rows: 2)
        #expect(pages == ["one two\nthree", "four five\nsix seven", "eight"])
    }

    @Test func exactlyRowsLinesIsOnePage() {
        #expect(TextPager.pages("a\nb\nc", columns: 10, rows: 3) == ["a\nb\nc"])
    }

    @Test func emptyTextIsOneEmptyPage() {
        #expect(TextPager.pages("", columns: 10, rows: 3) == [""])
    }

    @Test func nonPositiveGeometryReturnsTheWholeText() {
        #expect(TextPager.pages("a b c", columns: 0, rows: 3) == ["a b c"])
        #expect(TextPager.pages("a b c", columns: 5, rows: 0) == ["a b c"])
    }
}
