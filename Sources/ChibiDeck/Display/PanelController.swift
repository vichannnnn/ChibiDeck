import AppKit
import PanelCore

/// Plan 3 §4 and §5: puts the panel on the Edge and starts the touch reader when the Edge is there; shows the
/// preview and stops the reader when it is not. While Input Monitoring is not granted, re-checks every 5 s and
/// restarts the reader once it is, so the seize takes effect without a relaunch.
@MainActor
final class PanelController {
    static let permissionPollInterval: TimeInterval = 5

    private let model: AppModel
    private let locator = EdgeScreenLocator()
    private var panel: PanelWindow?
    private var preview: PreviewWindowController?
    private let reader = HIDTouchReader()
    private lazy var dispatcher = TouchDispatcher(model: model)
    private var permissionTimer: Timer?
    private var edgePresent = false
    private var inputMonitoringRequested = false

    init(model: AppModel) { self.model = model }

    func start() {
        reader.onEvent = { [weak self] event in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.dispatcher.handle(event) } }
        }
        reader.onModeChange = { [weak self] mode in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.noteTouchMode(mode) } }
        }
        locator.onChange = { [weak self] screen in self?.apply(screen: screen) }
        locator.start()
    }

    /// Menu bar: opens or raises the preview window at any time.
    func showPreview() {
        if preview == nil { preview = PreviewWindowController(model: model) }
        preview?.show()
    }

    private func apply(screen: NSScreen?) {
        edgePresent = screen != nil
        if let screen {
            if panel == nil { panel = PanelWindow(screen: screen, model: model) }
            panel?.setFrame(screen.frame, display: true)
            panel?.orderFrontRegardless()
            if !model.settings.previewAlwaysOpen { preview?.close() }
            startTouch()
        } else {
            panel?.orderOut(nil)
            stopTouch()
            // Automatic, so it must not steal the keyboard: an Edge unplug can land mid-keystroke in Terminal.
            if preview == nil { preview = PreviewWindowController(model: model) }
            preview?.show(activate: false)
        }
    }

    // MARK: - Touch (Plan 3 §5.1, §5.5)

    private func startTouch() {
        if AutomationPermission.inputMonitoring() != .granted, !inputMonitoringRequested {   // Plan 4 §8.3: one prompt per launch
            inputMonitoringRequested = true
            AutomationPermission.requestInputMonitoring()
        }
        model.permissions.inputMonitoring = AutomationPermission.inputMonitoring()
        reader.start()
        schedulePermissionPoll()
    }

    private func stopTouch() {
        reader.stop()
        permissionTimer?.invalidate()
        permissionTimer = nil
        model.permissions.touchOpenFailed = false
    }

    private func noteTouchMode(_ mode: HIDTouchReader.Mode) {
        if case .failed = mode { model.permissions.touchOpenFailed = true } else { model.permissions.touchOpenFailed = false }
    }

    private func schedulePermissionPoll() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        guard model.permissions.inputMonitoring != .granted else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: Self.permissionPollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.edgePresent else { return }
                let status = AutomationPermission.inputMonitoring()
                guard status != self.model.permissions.inputMonitoring else { return }
                self.model.permissions.inputMonitoring = status
                if status == .granted {
                    self.reader.stop()
                    self.reader.start()
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                }
            }
        }
    }
}
