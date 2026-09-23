import AppKit
import SwiftUI

/// Plan 3 §4: the development window on the main screen; the same content as the Edge at half size, resizable
/// with a locked 32:9 aspect. Closing it hides it; the app keeps running from the menu bar.
/// Spec 2026-09-23 §4.2: the hosting view exists only while the window is shown.
@MainActor
final class PreviewWindowController: NSObject, NSWindowDelegate {
    let window: NSWindow    // exposed so PanelController can tell ScrollWheelMonitor this window is in bounds (M1)
    private let model: AppModel
    private var hosting: NSView?

    init(model: AppModel) {
        self.model = model
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 360),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init()
        window.title = "Chibi Deck Preview"
        window.contentAspectRatio = NSSize(width: 32, height: 9)
        window.contentMinSize = NSSize(width: 640, height: 180)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
    }

    var isVisible: Bool { window.isVisible }

    /// `activate` is for development only: raising the window must never pull focus out of Terminal, so the
    /// automatic open on an Edge unplug passes `false` and only the menu bar's explicit request activates.
    func show(activate: Bool = true) {
        if hosting == nil {
            let view = NSHostingView(rootView: PanelScaler { PanelView() }.environment(model).background(Color.black))
            window.contentView = view
            hosting = view
        }
        window.makeKeyAndOrderFront(nil)
        if activate { NSApp.activate(ignoringOtherApps: true) }
    }

    func close() {
        window.orderOut(nil)
        dropContent()
    }

    /// The window's own close button.
    func windowWillClose(_ notification: Notification) { dropContent() }

    private func dropContent() {
        window.contentView = NSView()
        hosting = nil
    }
}
