import Foundation
import Observation
import PanelCore

@MainActor @Observable
final class PanelSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "themeId": ThemeLibrary.defaultThemeId, "quickReplies": "go,yes,no", "autoDimEnabled": false, "autoDimMinutes": 10,
            "sheetTimeoutSeconds": 30, "quietHoursEnabled": false, "quietHoursStart": "22:00", "quietHoursEnd": "07:00",
            "touchOffsetX": 0.0, "touchOffsetY": 0.0, "touchScaleX": 1.0, "touchScaleY": 1.0,
            "previewAlwaysOpen": false, "showInDock": true, "backgroundAgentMaxAgeHours": 24,
        ])
    }

    var themeId: String { get { access(keyPath: \.themeId); return defaults.string(forKey: "themeId") ?? ThemeLibrary.defaultThemeId }
                          set { withMutation(keyPath: \.themeId) { defaults.set(newValue, forKey: "themeId") } } }
    /// Plan 4 §9: the words an idle session's card and sheet offer to type, comma-separated; at most four are used.
    var quickReplies: String { get { access(keyPath: \.quickReplies); return defaults.string(forKey: "quickReplies") ?? "go,yes,no" }
                               set { withMutation(keyPath: \.quickReplies) { defaults.set(newValue, forKey: "quickReplies") } } }
    var autoDimEnabled: Bool { get { access(keyPath: \.autoDimEnabled); return defaults.bool(forKey: "autoDimEnabled") }
                               set { withMutation(keyPath: \.autoDimEnabled) { defaults.set(newValue, forKey: "autoDimEnabled") } } }
    var autoDimMinutes: Int { get { access(keyPath: \.autoDimMinutes); return defaults.integer(forKey: "autoDimMinutes") }
                              set { withMutation(keyPath: \.autoDimMinutes) { defaults.set(newValue, forKey: "autoDimMinutes") } } }
    var sheetTimeoutSeconds: Int { get { access(keyPath: \.sheetTimeoutSeconds); return defaults.integer(forKey: "sheetTimeoutSeconds") }
                                   set { withMutation(keyPath: \.sheetTimeoutSeconds) { defaults.set(newValue, forKey: "sheetTimeoutSeconds") } } }
    var quietHoursEnabled: Bool { get { access(keyPath: \.quietHoursEnabled); return defaults.bool(forKey: "quietHoursEnabled") }
                                  set { withMutation(keyPath: \.quietHoursEnabled) { defaults.set(newValue, forKey: "quietHoursEnabled") } } }
    var quietHoursStart: String { get { access(keyPath: \.quietHoursStart); return defaults.string(forKey: "quietHoursStart") ?? "22:00" }
                                  set { withMutation(keyPath: \.quietHoursStart) { defaults.set(newValue, forKey: "quietHoursStart") } } }
    var quietHoursEnd: String { get { access(keyPath: \.quietHoursEnd); return defaults.string(forKey: "quietHoursEnd") ?? "07:00" }
                                set { withMutation(keyPath: \.quietHoursEnd) { defaults.set(newValue, forKey: "quietHoursEnd") } } }
    var touchOffsetX: Double { get { access(keyPath: \.touchOffsetX); return defaults.double(forKey: "touchOffsetX") }
                               set { withMutation(keyPath: \.touchOffsetX) { defaults.set(newValue, forKey: "touchOffsetX") } } }
    var touchOffsetY: Double { get { access(keyPath: \.touchOffsetY); return defaults.double(forKey: "touchOffsetY") }
                               set { withMutation(keyPath: \.touchOffsetY) { defaults.set(newValue, forKey: "touchOffsetY") } } }
    var touchScaleX: Double { get { access(keyPath: \.touchScaleX); return defaults.double(forKey: "touchScaleX") }
                              set { withMutation(keyPath: \.touchScaleX) { defaults.set(newValue, forKey: "touchScaleX") } } }
    var touchScaleY: Double { get { access(keyPath: \.touchScaleY); return defaults.double(forKey: "touchScaleY") }
                              set { withMutation(keyPath: \.touchScaleY) { defaults.set(newValue, forKey: "touchScaleY") } } }
    /// A Dock icon lets the app be kept in the Dock (the bundle is LSUIElement, so this is applied at runtime).
    var showInDock: Bool { get { access(keyPath: \.showInDock); return defaults.bool(forKey: "showInDock") }
                           set { withMutation(keyPath: \.showInDock) { defaults.set(newValue, forKey: "showInDock") }; AppDelegate.applyActivationPolicy(showInDock: newValue) } }
    var previewAlwaysOpen: Bool { get { access(keyPath: \.previewAlwaysOpen); return defaults.bool(forKey: "previewAlwaysOpen") }
                                  set { withMutation(keyPath: \.previewAlwaysOpen) { defaults.set(newValue, forKey: "previewAlwaysOpen") } } }
    /// Spec 2026-09-07 §4: background agents older than this many hours are hidden; 0 disables.
    var backgroundAgentMaxAgeHours: Int { get { access(keyPath: \.backgroundAgentMaxAgeHours); return defaults.integer(forKey: "backgroundAgentMaxAgeHours") }
                                          set { withMutation(keyPath: \.backgroundAgentMaxAgeHours) { defaults.set(newValue, forKey: "backgroundAgentMaxAgeHours") } } }

    var quietHours: QuietHours {
        QuietHours(start: Self.hm(quietHoursStart) ?? (22, 0), end: Self.hm(quietHoursEnd) ?? (7, 0), enabled: quietHoursEnabled)
    }

    var touchCalibration: TouchCalibration {
        TouchCalibration(offsetX: touchOffsetX, offsetY: touchOffsetY, scaleX: touchScaleX == 0 ? 1 : touchScaleX, scaleY: touchScaleY == 0 ? 1 : touchScaleY)
    }

    static func hm(_ s: String) -> (Int, Int)? {
        let parts = s.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return (parts[0], parts[1])
    }
}
