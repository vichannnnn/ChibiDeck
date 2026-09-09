import Foundation
import Testing
@testable import PanelCore

@Suite struct TTYParserTests {
    @Test func mapsPsOutputToADevicePath() {
        #expect(TTYParser.devicePath("ttys004\n") == "/dev/ttys004")
        #expect(TTYParser.devicePath("  ttys012 ") == "/dev/ttys012")
    }

    @Test func rejectsNoTerminalAndGarbage() {
        #expect(TTYParser.devicePath("??\n") == nil)
        #expect(TTYParser.devicePath("") == nil)
        #expect(TTYParser.devicePath("\n") == nil)
        #expect(TTYParser.devicePath("../etc/passwd") == nil)
        #expect(TTYParser.devicePath("ttys004\nttys005\n") == nil)     // two lines cannot be one pid's answer
    }
}
