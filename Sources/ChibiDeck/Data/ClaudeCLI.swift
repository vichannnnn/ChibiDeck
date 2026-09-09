import Foundation

enum ClaudeCLI {
    static func locate() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func agentsJSON() async throws -> Data {
        guard let exe = locate() else { throw ShellError.launch("claude CLI not found") }
        return try await ShellRunner.run(exe, ["agents", "--json"], timeout: 10)
    }

    static func gitBranch(cwd: String) async -> String? {
        guard let data = try? await ShellRunner.run("/usr/bin/git", ["-C", cwd, "--no-optional-locks", "branch", "--show-current"], timeout: 5),
              let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }
}
