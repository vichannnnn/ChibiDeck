import AppKit
import SwiftUI
import PanelCore

/// Spec 2026-09-23 §8.4: the mouse wheel and the trackpad scroll the session grid in the panel and preview windows, by
/// the finger's rule: only over a card, its pill or the grid, and never under the sheet, the card menu or the character
/// select. Precise deltas move by their points over the window's scale, the way a standard scroll view moves; a notched
/// wheel moves one row per notch. The grid settles on a row 0.2 s after the last event (momentum included).
@MainActor
final class ScrollWheelMonitor {
    private let model: AppModel
    private var monitor: Any?
    private var settle: Task<Void, Never>?

    init(model: AppModel) { self.model = model }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.handle(event) ?? false }
            return consumed ? nil : event
        }
    }

    /// True when the event scrolled the grid; it is then consumed.
    private func handle(_ event: NSEvent) -> Bool {
        guard model.ui.selectedSessionId == nil, model.ui.menuSessionId == nil, model.ui.characterSelectOpenedAt == nil,
              let content = event.window?.contentView else { return false }
        let size = content.bounds.size
        let canvas = PanelScaler<EmptyView>.canvasSize
        let scale = min(size.width / canvas.width, size.height / canvas.height)
        guard scale > 0 else { return false }
        var p = content.convert(event.locationInWindow, from: nil)
        if !content.isFlipped { p.y = size.height - p.y }
        let x = (p.x - (size.width - canvas.width * scale) / 2) / scale
        let y = (p.y - (size.height - canvas.height * scale) / 2) / scale
        switch HitTester.hit(x: x, y: y, regions: model.touchRegions) {
        case .card, .cardAnswer, .sessionsGrid: break
        default: return false
        }
        if event.hasPreciseScrollingDeltas {
            model.scrollGrid(by: -event.scrollingDeltaY / scale)
        } else if event.scrollingDeltaY != 0 {
            model.scrollGrid(by: event.scrollingDeltaY > 0 ? -GridScroll.rowPitch : GridScroll.rowPitch)
        }
        settle?.cancel()
        settle = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.model.settleGrid()
        }
        return true
    }
}
