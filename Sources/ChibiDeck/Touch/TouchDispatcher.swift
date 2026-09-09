import Foundation
import PanelCore

/// Plan 3 §5.2: raw touch events → taps → points on the 2560×720 canvas → the registered region under the finger
/// → `AppModel.perform`. Every tap logs raw and canvas coordinates plus the target, so calibration values can be
/// set by hand with `defaults write` if taps land off.
/// Plan 6 §3: a half-second hold on a card is a long-press — noticed at the recogniser's deadline while the finger
/// rests, or on a late release — and opens the card's menu.
@MainActor
final class TouchDispatcher {
    static let canvas = (width: 2560.0, height: 720.0)

    private let model: AppModel
    private let recognizer = TapRecognizer()
    private let longPress = LongPressRecognizer()
    private var fireTask: Task<Void, Never>?

    init(model: AppModel) { self.model = model }

    func handle(_ event: TouchEvent) {
        if let press = longPress.handle(event) { open(press) }        // Plan 6 §3: a late release
        scheduleFire()
        guard let tap = recognizer.handle(event) else { return }
        let point = CoordinateMapper.map(rawX: tap.rawX, rawY: tap.rawY, to: Self.canvas, calibration: model.settings.touchCalibration)
        let target = HitTester.hit(x: point.x, y: point.y, regions: model.touchRegions)
        let name = target.map { String(describing: $0) } ?? "none"
        touchLog.info("tap raw=(\(tap.rawX),\(tap.rawY)) canvas=(\(Int(point.x)),\(Int(point.y))) target=\(name, privacy: .public) regions=\(self.model.touchRegions.count)")
        model.ui.noteTouch()
        if let target { model.perform(target) }
    }

    /// Plan 6 §3: while the finger rests, `fire` runs at the recogniser's deadline; every newer event re-arms or clears it.
    private func scheduleFire() {
        fireTask?.cancel()
        fireTask = nil
        guard let deadline = longPress.deadline else { return }
        let wait = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        fireTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(wait), clock: .suspending)   // the deadline is systemUptime, which also pauses while the Mac sleeps
            guard !Task.isCancelled, let self,
                  let press = self.longPress.fire(at: ProcessInfo.processInfo.systemUptime) else { return }
            self.open(press)
        }
    }

    /// Plan 6 §3: a long-press on a card (or its pill) opens that card's menu; anywhere else it only counts as a touch.
    private func open(_ press: LongPress) {
        let point = CoordinateMapper.map(rawX: press.rawX, rawY: press.rawY, to: Self.canvas, calibration: model.settings.touchCalibration)
        let target = HitTester.hit(x: point.x, y: point.y, regions: model.touchRegions)
        let name = target.map { String(describing: $0) } ?? "none"
        touchLog.info("long-press raw=(\(press.rawX),\(press.rawY)) canvas=(\(Int(point.x)),\(Int(point.y))) target=\(name, privacy: .public)")
        switch target {
        case .card(let id), .cardAnswer(let id): model.perform(.cardMenu(id))
        default: model.ui.noteTouch()
        }
    }
}
