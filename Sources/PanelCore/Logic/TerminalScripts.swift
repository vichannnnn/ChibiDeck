import Foundation

/// Plan 3 §6.2–6.3: the AppleScript the Terminal bridge runs, and how its reply maps to an `ActionResult`.
/// Pure text, so the escaping and the not-found paths are unit-tested; the app target only executes the strings.
public enum TerminalScripts {
    /// Backslashes and double quotes escaped for an AppleScript string literal; line breaks become spaces so
    /// `do script` sends exactly one line.
    public static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    /// Handoff §5: backslashes and double quotes escaped, line breaks kept (`\r\n` and `\r` become `\n`). An
    /// AppleScript string literal may span lines, and Terminal delivers the whole `do script` text in one burst,
    /// which Claude Code takes for a paste and keeps as one message (verified 2026-09-08 with a 7 KiB block).
    public static func escapeMultiline(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    /// Selects the tab whose tty matches, brings its window to the front and activates Terminal. Not found:
    /// Terminal is activated anyway and the script replies `notfound`.
    public static func focus(tty: String) -> String {
        script(tty: tty,
               matched: ["set selected tab of w to t", "set index of w to 1", "activate", "return \"ok\""],
               notFound: ["activate", "return \"notfound\""])
    }

    /// Types `text` into the matching tab and submits it with a separate Enter (Plan 4 §2: Claude Code can take a
    /// fast burst for a paste and keep its newline as a line break; a bare Enter always submits). Empty text sends
    /// Enter alone, which is how a permission dialog is approved. Not found: nothing is typed (a `do script`
    /// without a target would open a new window).
    public static func send(text: String, tty: String) -> String {
        let typed = text.isEmpty ? [] : ["do script \"\(escape(text))\" in t", "delay 0.4"]
        return script(tty: tty, matched: typed + ["do script \"\" in t", "return \"ok\""], notFound: ["return \"notfound\""])
    }

    /// Handoff §5: types a multi-line block into the matching tab as one paste, waits a second for the TUI to
    /// settle it, then submits with a bare Enter. Not found: nothing is typed.
    public static func paste(text: String, tty: String) -> String {
        script(tty: tty,
               matched: ["do script \"\(escapeMultiline(text))\" in t", "delay 1", "do script \"\" in t", "return \"ok\""],
               notFound: ["return \"notfound\""])
    }

    /// The `try` around the tab loop is load-bearing: Terminal's Settings and Inspector windows raise −1728 on
    /// `tabs of w`, which would abort the whole script before the real windows were searched.
    static func script(tty: String, matched: [String], notFound: [String]) -> String {
        let inner = matched.map { "\t\t\t\t\t\t" + $0 }.joined(separator: "\n")
        let tail = notFound.map { "\t\t" + $0 }.joined(separator: "\n")
        return """
        with timeout of 3 seconds
        \ttell application "Terminal"
        \t\trepeat with w in windows
        \t\t\ttry
        \t\t\t\trepeat with t in tabs of w
        \t\t\t\t\tif tty of t is "\(escape(tty))" then
        \(inner)
        \t\t\t\t\tend if
        \t\t\t\tend repeat
        \t\t\tend try
        \t\tend repeat
        \(tail)
        \tend tell
        end timeout
        """
    }

    /// `reply` is the script's return value; `errorNumber` is `NSAppleScript.errorNumber` when the run failed.
    public static func outcome(reply: String?, errorNumber: Int?) -> ActionResult {
        if let n = errorNumber {
            switch n {
            case -1743: return .failed("Terminal automation denied")      // errAEEventNotPermitted
            case -1712: return .failed("Terminal didn't answer")          // errAETimeout
            default: return .failed("Terminal error \(n)")
            }
        }
        switch reply {
        case "ok": return .done
        case "notfound": return .failed("couldn't find the tab")
        default: return .failed("Terminal gave no answer")
        }
    }
}
