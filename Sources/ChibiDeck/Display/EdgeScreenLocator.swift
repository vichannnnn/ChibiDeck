import AppKit
import PanelCore
import os

let displayLog = Logger(subsystem: "me.himaa.chibideck", category: "display")

/// Plan 3 §4: finds the Edge among the attached screens and reports when that answer changes.
@MainActor
final class EdgeScreenLocator {
    private(set) var edgeScreen: NSScreen?
    var onChange: ((NSScreen?) -> Void)?
    private var observer: NSObjectProtocol?

    /// By name first (`XENEON` and ultra-wide, Plan 4 §8.9), then by the Edge's native 2560×720 points, then its HiDPI 1280×360 points.
    static func find(in screens: [NSScreen] = NSScreen.screens) -> NSScreen? {
        if let byName = screens.first(where: { EdgeScreenMatch.isEdge(name: $0.localizedName, width: $0.frame.width, height: $0.frame.height) }) { return byName }
        if let native = screens.first(where: { $0.frame.size == CGSize(width: 2560, height: 720) }) { return native }
        return screens.first { $0.frame.size == CGSize(width: 1280, height: 360) }
    }

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh(force: true)
    }

    private func refresh(force: Bool = false) {
        let found = Self.find()
        let changed = force || Self.identity(found) != Self.identity(edgeScreen)
        edgeScreen = found
        guard changed else { return }
        if let found {
            displayLog.info("Edge screen: \(found.localizedName, privacy: .public) \(Int(found.frame.width))×\(Int(found.frame.height)) at (\(Int(found.frame.origin.x)), \(Int(found.frame.origin.y)))")
        } else {
            displayLog.info("Edge screen: none")
        }
        onChange?(found)
    }

    /// Display id plus frame: `NSScreen` objects are recreated on parameter changes, so object identity is not stable.
    private static func identity(_ screen: NSScreen?) -> String? {
        guard let screen else { return nil }
        let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
        return "\(id)-\(NSStringFromRect(screen.frame))"
    }
}
