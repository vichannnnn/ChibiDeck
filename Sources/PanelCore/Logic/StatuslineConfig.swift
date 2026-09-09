import Foundation

/// Plan 3 §8.3: where Claude Code's statusline script lives, read from `~/.claude/settings.json`
/// (`statusLine.command`, e.g. `bash ~/.claude/statusline-command.sh`). Mirrors the rule in
/// `Scripts/install-statusline.sh`: the first whitespace-separated token ending in `.sh`, with `~` expanded.
public enum StatuslineConfig {
    public static func scriptPath(settingsJSON: Data, home: String) -> String? {
        guard let o = (try? JSONSerialization.jsonObject(with: settingsJSON)) as? [String: Any],
              let statusLine = o["statusLine"] as? [String: Any],
              let command = statusLine["command"] as? String else { return nil }
        return scriptPath(command: command, home: home)
    }

    public static func scriptPath(command: String, home: String) -> String? {
        for token in command.split(whereSeparator: { $0 == " " || $0 == "\t" }) {
            var path = String(token).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard path.hasSuffix(".sh") else { continue }
            if path == "~" || path.hasPrefix("~/") { path = home + path.dropFirst() }
            return path
        }
        return nil
    }
}

/// Plan 3 §8.2–8.3: the hook line ends with this marker; its presence means the feed is installed.
public enum FeedInstallState {
    public static let marker = "# chibideck-feed"
    public static let anchor = "input=$(cat)"

    public static func isInstalled(scriptText: String) -> Bool {
        scriptText.contains(marker)
    }
}
