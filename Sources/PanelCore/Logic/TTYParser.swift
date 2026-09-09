import Foundation

/// Plan 3 §6.1: `ps -o tty= -p <pid>` prints `ttys004` (or `??` when the process has no terminal).
public enum TTYParser {
    public static func devicePath(_ psOutput: String) -> String? {
        let name = psOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != "??", name.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return "/dev/\(name)"
    }
}
