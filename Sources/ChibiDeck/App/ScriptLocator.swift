import AppKit

/// Plan 3 §8.3: where the installer script lives (bundled, or in the source tree under `swift run`) and how to
/// run it in Terminal so the diff and the `Apply? [y/N]` question reach the user. The app process never edits
/// the statusline script itself.
enum ScriptLocator {
    static var installStatusline: URL {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Scripts/install-statusline.sh"),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        // Under `swift run` the executable sits at <package>/.build/<triple>/debug/ChibiDeck, so the package root is
        // four levels up; the working directory is the second guess. No `#filePath`: a release binary must not
        // carry the build machine's paths (Scripts/bundle.sh checks).
        var candidates: [URL] = []
        if let exe = Bundle.main.executableURL {
            var root = exe
            for _ in 0..<4 { root.deleteLastPathComponent() }
            candidates.append(root)
        }
        candidates.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        let scripts = candidates.map { $0.appendingPathComponent("Scripts/install-statusline.sh") }
        return scripts.first { FileManager.default.fileExists(atPath: $0.path) } ?? scripts[0]
    }

    /// Terminal.app runs an executable shell script it is asked to open, in a new window. No Automation
    /// permission is involved (this is Launch Services, not an Apple event).
    static func openInTerminal(_ script: URL) {
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([script], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }
}
