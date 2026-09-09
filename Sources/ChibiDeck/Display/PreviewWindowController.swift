import AppKit
import SwiftUI

/// Plan 3 §4: the development window on the main screen; the same content as the Edge at half size, resizable
/// with a locked 32:9 aspect. Closing it hides it; the app keeps running from the menu bar.
@MainActor
final class PreviewWindowController {
    private let window: NSWindow

    init(model: AppModel) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 360),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Chibi Deck Preview"
        window.contentAspectRatio = NSSize(width: 32, height: 9)
        window.contentMinSize = NSSize(width: 640, height: 180)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PanelScaler { PanelView() }.environment(model).background(Color.black))
        window.center()
    }

    var isVisible: Bool { window.isVisible }

    /// `activate` is for development only: raising the window must never pull focus out of Terminal, so the
    /// automatic open on an Edge unplug passes `false` and only the menu bar's explicit request activates.
    func show(activate: Bool = true) {
        window.makeKeyAndOrderFront(nil)
        if activate { NSApp.activate(ignoringOtherApps: true) }
    }

    func close() { window.orderOut(nil) }
}
