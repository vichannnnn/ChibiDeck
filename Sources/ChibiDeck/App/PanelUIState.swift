import Foundation
import Observation

@MainActor @Observable
final class PanelUIState {
    var selectedSessionId: String?
    var sheetOpenedAt: Date?
    var isDimmed = false
    var lastTouch: Date?
    var toast: String?
    /// Plan 4 §6.1: which page of the Claude text the sheet shows; a fresh sheet starts at the first.
    var sheetPage = 0
    /// Plan 6 §5: the card whose menu is open, and when it opened (the 6 s auto-close counts from here).
    var menuSessionId: String?
    var menuOpenedAt: Date?
    /// Character select §6: when the screen opened (nil = closed); the 10 s auto-close counts from here.
    var characterSelectOpenedAt: Date?

    func openSheet(for sessionId: String, now: Date = Date()) {
        sheetPage = 0
        selectedSessionId = sessionId
        sheetOpenedAt = now
    }

    func closeSheet() {
        selectedSessionId = nil
        sheetOpenedAt = nil
    }

    func openMenu(for sessionId: String, now: Date = Date()) {
        menuSessionId = sessionId
        menuOpenedAt = now
    }

    func closeMenu() {
        menuSessionId = nil
        menuOpenedAt = nil
    }

    func openCharacterSelect(now: Date = Date()) { characterSelectOpenedAt = now }
    func closeCharacterSelect() { characterSelectOpenedAt = nil }

    func noteTouch(now: Date = Date()) {
        lastTouch = now
        isDimmed = false
    }
}
