import Foundation

/// Plan 3 §5.4: the sheet's pills and `AppModel.perform` agree on when Focus tab and an answer may run.
/// Background agents have no tty and no reply channel (§2), so neither action applies to them.
public enum ActionAvailability {
    public static func canFocus(_ session: Session, actionsAvailable: Bool) -> Bool {
        actionsAvailable && session.kind == .interactive && session.pid != nil
    }

    /// Plan 4 §5.3: an answer may be typed while the session waits for one or sits idle at its prompt.
    public static func canAnswer(_ session: Session, actionsAvailable: Bool) -> Bool {
        canFocus(session, actionsAvailable: actionsAvailable) && (session.status == .waiting || session.status == .idle)
    }

    /// Handoff §3: the menu's Handoff row — a Focus-able session that is busy (`/handoff` queues behind the turn) or
    /// idle, with no sequence already running for its pid. Never a waiting one: typed text plus Enter would answer
    /// the dialog instead (review 2026-09-08).
    public static func canHandoff(_ session: Session, actionsAvailable: Bool, running: Bool) -> Bool {
        canFocus(session, actionsAvailable: actionsAvailable) && !running && (session.status == .busy || session.status == .idle)
    }
}
