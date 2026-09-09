import Foundation
import Testing
@testable import PanelCore

@Suite struct StatuslineConfigTests {
    static let home = "/Users/dev"

    @Test func extractsTheScriptPathFromTheCommand() {
        let json = #"{"statusLine":{"type":"command","command":"bash ~/.claude/statusline-command.sh"}}"#.data(using: .utf8)!
        #expect(StatuslineConfig.scriptPath(settingsJSON: json, home: Self.home) == "/Users/dev/.claude/statusline-command.sh")
        #expect(StatuslineConfig.scriptPath(command: "/opt/x/status.sh", home: Self.home) == "/opt/x/status.sh")
        #expect(StatuslineConfig.scriptPath(command: "sh '~/bin/line.sh' --fast", home: Self.home) == "/Users/dev/bin/line.sh")
    }

    @Test func inlineCommandsAndMissingKeysGiveNil() {
        #expect(StatuslineConfig.scriptPath(command: "echo hi", home: Self.home) == nil)
        #expect(StatuslineConfig.scriptPath(command: "node ~/x.js", home: Self.home) == nil)
        #expect(StatuslineConfig.scriptPath(settingsJSON: #"{"theme":"dark"}"#.data(using: .utf8)!, home: Self.home) == nil)
        #expect(StatuslineConfig.scriptPath(settingsJSON: "nope".data(using: .utf8)!, home: Self.home) == nil)
        #expect(StatuslineConfig.scriptPath(settingsJSON: #"{"statusLine":{"type":"command"}}"#.data(using: .utf8)!, home: Self.home) == nil)
    }

    @Test func installStateLooksForTheMarker() {
        #expect(FeedInstallState.marker == "# chibideck-feed")
        #expect(FeedInstallState.isInstalled(scriptText: "input=$(cat)\n{ x; } || true  # chibideck-feed\n"))
        #expect(!FeedInstallState.isInstalled(scriptText: "input=$(cat)\necho hi\n"))
        #expect(!FeedInstallState.isInstalled(scriptText: ""))
    }
}
