import AppKit
import IOKit.hid
import PanelCore

enum PermissionStatus: Equatable {
    case granted, denied, notDetermined, unknown
}

/// Plan 3 §7: what the left column's permission lines and the menu bar show.
struct PermissionState: Equatable {
    var inputMonitoring: PermissionStatus = .unknown
    var automation: PermissionStatus = .unknown
    /// The HID open failed for a reason other than permission (§5.1 `mode = .failed`).
    var touchOpenFailed = false

    /// The lines under the character, in order; empty when nothing is denied.
    var lines: [String] {
        var out: [String] = []
        if inputMonitoring == .denied { out.append("touch: needs Input Monitoring") }
        else if touchOpenFailed { out.append("touch: device open failed") }
        if automation == .denied { out.append("actions: Terminal automation denied") }
        return out
    }
}

/// Plan 3 §5.5 and §6.4: the two TCC states the panel depends on, read without prompting.
enum AutomationPermission {
    static let terminalBundleId = "com.apple.Terminal"

    /// `AEDeterminePermissionToAutomateTarget` for Terminal.app: `noErr` granted, −1743 denied, −1744 not yet asked,
    /// −600 Terminal not running (unknown, treated as available).
    static func automation() -> PermissionStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: terminalBundleId)
        guard let desc = target.aeDesc else { return .unknown }
        let status = AEDeterminePermissionToAutomateTarget(desc, AEEventClass(typeWildCard), AEEventID(typeWildCard), false)
        switch status {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(errAEEventWouldRequireUserConsent): return .notDetermined
        default: return .unknown
        }
    }

    static func inputMonitoring() -> PermissionStatus {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied: return .denied
        default: return .notDetermined
        }
    }

    /// Plan 3 §5.5: shows the system's Input Monitoring prompt (a no-op once the user has decided).
    static func requestInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func openInputMonitoringSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    static func openAutomationSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    private static func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
