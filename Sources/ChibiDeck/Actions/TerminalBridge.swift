import AppKit
import PanelCore
import os

private let actionsLog = Logger(subsystem: "me.himaa.chibideck", category: "actions")

/// Plan 3 §6, Plan 4 §5.3: Focus tab and the typed answer over Terminal.app. The pid's tty comes from `ps`
/// (cached an hour; a pid's tty never changes); one AppleScript per action, run with `NSAppleScript` on the main
/// actor (Apple Events are not thread-safe) and bounded by the script's own 3 s timeout. Background agents have
/// no channel (§2).
@MainActor
final class TerminalBridge: PanelActions {
    private var ttyCache = ExpiringCache<Int, String>(ttl: 3600)
    private(set) var automation: PermissionStatus = .unknown
    var onPermissionChange: ((PermissionStatus) -> Void)?

    var isAvailable: Bool { automation != .denied }

    /// Plan 3 §6.4: re-read the TCC state without prompting (when the sheet opens, and after every action).
    func refreshPermission() { setPermission(AutomationPermission.automation()) }

    func focusTab(_ session: Session) async -> ActionResult {
        guard session.kind == .interactive, let pid = session.pid else { return .unavailable("no channel") }
        guard let tty = await tty(for: pid) else { return .failed("no tty for pid \(pid)") }
        return run(TerminalScripts.focus(tty: tty), what: "focus", pid: pid)
    }

    /// Plan 4 final review: nothing is typed at a dead pid. Between a session's exit and the next listing (≤ 5 s, longer
    /// if `agents --json` fails) its card still stands; without this check the tty — cached an hour — is the user's own
    /// shell prompt, and a tap would run the answer there. `kill(pid, 0)` failing at all means gone (the user's sessions
    /// are their own, so EPERM cannot happen). `focusTab` is left alone: focusing a finished tab is harmless.
    func sendLine(_ session: Session, text: String) async -> ActionResult {
        switch await typingChannel(for: session) {
        case .closed(let result): return result
        case .open(let pid, let tty): return run(TerminalScripts.send(text: text, tty: tty), what: text.isEmpty ? "enter" : "send", pid: pid)
        }
    }

    /// Handoff §5: the block goes in as one paste (`TerminalScripts.paste` keeps its line breaks), then Enter.
    func pasteBlock(_ session: Session, text: String) async -> ActionResult {
        switch await typingChannel(for: session) {
        case .closed(let result): return result
        case .open(let pid, let tty): return run(TerminalScripts.paste(text: text, tty: tty), what: "paste \(text.utf8.count) bytes", pid: pid)
        }
    }

    private enum TypingChannel {
        case open(pid: Int, tty: String)
        case closed(ActionResult)
    }

    /// The checks every typed action shares: interactive with a pid, the pid still alive, a tty for it.
    private func typingChannel(for session: Session) async -> TypingChannel {
        guard session.kind == .interactive, let pid = session.pid else { return .closed(.unavailable("no channel")) }
        guard kill(pid_t(pid), 0) == 0 else {
            actionsLog.info("send: pid \(pid, privacy: .public) has exited; nothing typed")
            return .closed(.failed("session exited"))
        }
        guard let tty = await tty(for: pid) else { return .closed(.failed("no tty for pid \(pid)")) }
        return .open(pid: pid, tty: tty)
    }

    private func tty(for pid: Int) async -> String? {
        if let cached = ttyCache.value(for: pid, now: Date()) { return cached }
        guard let data = try? await ShellRunner.run("/bin/ps", ["-o", "tty=", "-p", String(pid)], timeout: 3),
              let tty = TTYParser.devicePath(String(decoding: data, as: UTF8.self)) else { return nil }
        ttyCache.set(tty, for: pid, now: Date())
        return tty
    }

    private func run(_ source: String, what: String, pid: Int) -> ActionResult {
        guard let script = NSAppleScript(source: source) else {              // Plan 4 §8.2: not a permission signal
            actionsLog.error("\(what, privacy: .public): script did not compile")
            return .failed("script did not compile")
        }
        var error: NSDictionary?
        let reply = script.executeAndReturnError(&error)
        let number = error?[NSAppleScript.errorNumber] as? Int
        let result = TerminalScripts.outcome(reply: reply.stringValue, errorNumber: number)
        if number == Int(errAEEventNotPermitted) { setPermission(.denied) } else if number == nil { setPermission(.granted) }
        if reply.stringValue == "notfound" { ttyCache.remove(pid) }          // Plan 4 §8.2: the tab moved or closed; look again next time
        actionsLog.info("\(what, privacy: .public): \(String(describing: result), privacy: .public)")
        return result
    }

    private func setPermission(_ status: PermissionStatus) {
        guard status != automation else { return }
        automation = status
        onPermissionChange?(status)
    }
}
