import Foundation

/// Spec 2026-09-07 (Plan 3) §10.1. SwiftPM's generated `Bundle.module` looks for the resource bundle beside
/// `Contents/` inside a `.app`, where `codesign` refuses it ("unsealed contents"), so `Scripts/bundle.sh`
/// places it in `Contents/Resources` and this lookup tries that first. `swift run` finds it next to the
/// executable (`Bundle.main.resourceURL` is the executable's folder for a bare binary); `swift test` falls
/// through to `Bundle.module`.
public enum PanelResources {
    public static let bundleName = "ChibiDeck_PanelCore.bundle"

    public static let bundle: Bundle = {
        let candidates = [Bundle.main.resourceURL, Bundle.main.bundleURL].compactMap { $0?.appendingPathComponent(bundleName) }
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let found = Bundle(url: url) { return found }
        }
        return Bundle.module
    }()

    /// Resources of one extension in one subdirectory, sorted by file name for a stable load order.
    public static func urls(extension ext: String, subdirectory: String) -> [URL] {
        (bundle.urls(forResourcesWithExtension: ext, subdirectory: subdirectory) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
