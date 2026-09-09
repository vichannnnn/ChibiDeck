import Foundation
import PanelCore

/// Implemented by `TerminalBridge` (Plan 3 §6). `AppModel.perform` and the sheet consult `isAvailable` through
/// `ActionAvailability`.
@MainActor
protocol PanelActions: AnyObject {
    var isAvailable: Bool { get }
    func focusTab(_ session: Session) async -> ActionResult
    /// Plan 4 §5.3: types `text` into the session's tab and presses Enter; empty text presses Enter alone.
    func sendLine(_ session: Session, text: String) async -> ActionResult
    /// Handoff §5: types a multi-line block into the session's tab as one paste and presses Enter.
    func pasteBlock(_ session: Session, text: String) async -> ActionResult
}
