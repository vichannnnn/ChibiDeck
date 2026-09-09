import AppKit
import SwiftUI

/// Plan 3 §4: the borderless, non-activating panel that covers the Edge. It never becomes key, so a tap or a
/// mouse click on it never steals the keyboard from Terminal. Content is the same `PanelScaler { PanelView() }`
/// as the preview, so a HiDPI Edge (1280×360 points) is scaled by 0.5 exactly as the preview is.
final class PanelWindow: NSPanel {
    init(screen: NSScreen, model: AppModel) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        ignoresMouseEvents = false
        backgroundColor = .black
        hasShadow = false
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: PanelScaler { PanelView() }.environment(model))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
