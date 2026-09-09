import Foundation
import Testing
@testable import PanelCore

@Suite struct TerminalScriptsTests {
    @Test func escapesQuotesBackslashesAndLineBreaks() {
        #expect(TerminalScripts.escape(#"say "hi" \ now"#) == #"say \"hi\" \\ now"#)
        #expect(TerminalScripts.escape("one\r\ntwo\nthree\rfour") == "one two three four")
        #expect(TerminalScripts.escape("Continue") == "Continue")
    }

    @Test func focusScriptSelectsAndActivatesWithoutTyping() {
        let s = TerminalScripts.focus(tty: "/dev/ttys004")
        #expect(s.hasPrefix("with timeout of 3 seconds"))
        #expect(s.hasSuffix("end timeout"))
        #expect(s.contains(#"if tty of t is "/dev/ttys004" then"#))
        #expect(s.contains("set selected tab of w to t"))
        #expect(s.contains("set index of w to 1"))
        #expect(!s.contains("do script"))
        #expect(s.components(separatedBy: "activate").count == 3)        // once when matched, once when not found
        #expect(s.components(separatedBy: #"return "notfound""#).count == 2)
        #expect(s.contains("\t\t\ttry\n\t\t\t\trepeat with t in tabs of w"))
        #expect(s.contains("\t\t\tend try"))
    }

    @Test func sendScriptTypesThenEntersInsideTheMatchedBranch() throws {
        let s = TerminalScripts.send(text: #"go "now""#, tty: "/dev/ttys004")
        #expect(s.components(separatedBy: "do script").count == 3)       // the text, then a bare Enter
        #expect(s.contains(#"do script "go \"now\"" in t"#))
        #expect(s.contains("delay 0.4"))
        #expect(s.contains(#"do script "" in t"#))
        #expect(!s.contains("activate"))
        #expect(!s.contains("set selected tab"))
        let lines = s.components(separatedBy: "\n")
        let typed = try #require(lines.firstIndex { $0.contains(#"do script "go"#) })
        let delay = try #require(lines.firstIndex { $0.contains("delay 0.4") })
        let enter = try #require(lines.firstIndex { $0.contains(#"do script "" in t"#) })
        let endIf = try #require(lines.firstIndex { $0.contains("end if") })
        #expect(typed < delay && delay < enter && enter < endIf)
        #expect(lines.last { $0.contains("return") }?.contains("notfound") == true)
        #expect(s.contains("\t\t\ttry\n\t\t\t\trepeat with t in tabs of w"))
        #expect(s.contains("\t\t\tend try"))
    }

    @Test func emptyTextSendsEnterAlone() {
        let s = TerminalScripts.send(text: "", tty: "/dev/ttys004")
        #expect(s.components(separatedBy: "do script").count == 2)
        #expect(s.contains(#"do script "" in t"#))
        #expect(!s.contains("delay"))
    }

    @Test func outcomesMapRepliesAndErrors() {
        #expect(TerminalScripts.outcome(reply: "ok", errorNumber: nil) == .done)
        #expect(TerminalScripts.outcome(reply: "notfound", errorNumber: nil) == .failed("couldn't find the tab"))
        #expect(TerminalScripts.outcome(reply: nil, errorNumber: -1743) == .failed("Terminal automation denied"))
        #expect(TerminalScripts.outcome(reply: nil, errorNumber: -1712) == .failed("Terminal didn't answer"))
        #expect(TerminalScripts.outcome(reply: nil, errorNumber: -600) == .failed("Terminal error -600"))
        #expect(TerminalScripts.outcome(reply: "ok", errorNumber: -1743) == .failed("Terminal automation denied"))   // an error wins
        #expect(TerminalScripts.outcome(reply: nil, errorNumber: nil) == .failed("Terminal gave no answer"))
    }

    @Test func escapeMultilineKeepsLineBreaks() {
        #expect(TerminalScripts.escapeMultiline("a \"b\" \\ c\r\nd\re\nf") == "a \\\"b\\\" \\\\ c\nd\ne\nf")
        #expect(TerminalScripts.escapeMultiline("plain") == "plain")
    }

    @Test func pasteScriptTypesTheBlockWithItsLineBreaksThenEnters() throws {
        let s = TerminalScripts.paste(text: "GOAL\nfix \"it\"\n\nDONE", tty: "/dev/ttys004")
        #expect(s.components(separatedBy: "do script").count == 3)       // the block, then a bare Enter
        #expect(s.contains("do script \"GOAL\nfix \\\"it\\\"\n\nDONE\" in t"))
        #expect(s.contains(#"do script "" in t"#))
        #expect(!s.contains("delay 0.4"))
        #expect(!s.contains("activate"))
        let lines = s.components(separatedBy: "\n")
        let delay = try #require(lines.firstIndex { $0.contains("delay 1") })
        let enter = try #require(lines.firstIndex { $0.contains(#"do script "" in t"#) })
        let endIf = try #require(lines.firstIndex { $0.contains("end if") })
        #expect(delay < enter && enter < endIf)
        #expect(lines.last { $0.contains("return") }?.contains("notfound") == true)
    }

    /// Compiling sends no Apple Event; it is the one proof that the multi-line literal is valid AppleScript.
    @Test func pasteScriptCompiles() throws {
        let block = "You are continuing work.\n\tsay \"hi\" \\ now\r\n```bash\nswift test\n```\nÜber — 日本語 ✓\n"
        let source = TerminalScripts.paste(text: block, tty: "/dev/ttys004")
        let script = try #require(NSAppleScript(source: source))
        var error: NSDictionary?
        let compiled = script.compileAndReturnError(&error)
        #expect(compiled, "\(error ?? [:])")
        #expect(!source.contains("\r"))
    }
}
