import AppKit
import os

private let appLog = Logger(subsystem: "me.himaa.chibideck", category: "app")

/// Plan 3 §4 and §10.4: owns the one `AppModel` and the window controller; a second bundled instance exits at once.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private(set) lazy var panels = PanelController(model: model)

    func applicationDidFinishLaunching(_ notification: Notification) {
        exitIfAnotherInstanceRuns()
        // The bundled app is an accessory through LSUIElement in its Info.plist. A bare `swift run` binary has no
        // Info.plist, so it asks for the regular policy to let the preview window take focus during development.
        migrateFromCorsairDisplay()
        Self.applyActivationPolicy(showInDock: model.settings.showInDock)
        model.start()
        panels.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// A click on the Dock icon (or `open -a`) while running: show the preview window instead of nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panels.showPreview()
        return false
    }

    /// The bundle is LSUIElement (no Dock icon, no activation at login), and the Dock icon is added at runtime when the
    /// `showInDock` setting says so, so the app can be kept in the Dock. A bare `swift run` binary has no Info.plist
    /// and always takes the regular policy so the preview window can take focus during development.
    static func applyActivationPolicy(showInDock: Bool) {
        let regular = showInDock || Bundle.main.bundleIdentifier == nil
        NSApp.setActivationPolicy(regular ? .regular : .accessory)
    }

    /// Rename of 2026-09-08: carry the `CorsairDisplay` install's data over once. The Application Support folder is
    /// moved (burn index, feed files) and the old defaults domain (`themeId`, quick replies, calibration…) is copied
    /// into this one, then deleted. TCC grants cannot be copied; the menu asks for them again.
    private func migrateFromCorsairDisplay() {
        _ = ClaudePaths.appSupportDir
        if ClaudePaths.movedLegacyAppSupportFolder { appLog.notice("moved Application Support/CorsairDisplay to ChibiDeck") }
        guard let bundleId = Bundle.main.bundleIdentifier, bundleId == "me.himaa.chibideck" else { return }
        let legacyDomain = "me.himaa.corsairdisplay"
        let defaults = UserDefaults.standard
        guard let old = defaults.persistentDomain(forName: legacyDomain), !old.isEmpty else { return }
        // Compare against the persistent domain, not `object(forKey:)`: PanelSettings has already registered defaults
        // for every key, so `object(forKey:)` is never nil here and the user's values would be skipped.
        let current = defaults.persistentDomain(forName: bundleId) ?? [:]
        for (key, value) in old where current[key] == nil { defaults.set(value, forKey: key) }
        defaults.removePersistentDomain(forName: legacyDomain)
        appLog.notice("copied \(old.count) defaults from \(legacyDomain, privacy: .public)")
    }

    private func exitIfAnotherInstanceRuns() {
        guard let id = Bundle.main.bundleIdentifier else { return }
        let me = ProcessInfo.processInfo.processIdentifier
        if NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0.processIdentifier != me }) {
            appLog.notice("another ChibiDeck instance is running; exiting")
            exit(0)
        }
    }
}
