import Foundation

extension CGRect {
    init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
    }
}

/// Plan 3 §5.3–5.4: everything a tap on the panel can mean. The SwiftUI views register a region per target and
/// `AppModel.perform(_:)` carries out the action, so mouse and touch share one path.
public enum TouchTarget: Hashable, Sendable {
    case mascot
    case card(String)
    /// Plan 4 §5.3: the answer pill on a card (`Allow ↵` or the first quick reply).
    case cardAnswer(String)
    /// Plan 4 §6.2: the i-th answer pill on the sheet.
    case sheetAnswer(Int)
    case sheetBackdrop
    case sheetBack
    case sheetFocus
    /// Handoff §3: the sheet's Handoff pill — the same sequence the menu row starts.
    case sheetHandoff
    case sheetDismiss
    /// Plan 4 §5.4: removes the card until that session leaves the listing.
    case sheetHide
    /// Plan 4 §6.1: page the Claude text one page up or down.
    case sheetPageUp
    case sheetPageDown
    /// Plan 6 §3: a long hold on a card opens its menu (the dispatcher's long-press and the mouse gesture both send it).
    case cardMenu(String)
    /// Plan 6 §4–5: the menu's rows, and the backdrop that closes it.
    case menuFocus
    /// Handoff §3: the menu's second row — `/handoff`, then `/clear`, then the block pasted back.
    case menuHandoff
    case menuDismiss
    case menuHide
    case menuClose
    /// Character select §3: a long hold on the mascot (the dispatcher's long-press and the mouse gesture both send it).
    case characterSelect
    /// Character select §6: a tile — the theme id it picks — and the backdrop that closes the screen.
    case characterPick(String)
    case characterSelectClose
    /// Spec 2026-09-23 §8.3: the grid viewport between and behind the cards (z −1); a drag that starts here scrolls
    /// the grid, a tap does nothing.
    case sessionsGrid
}

/// A tappable rectangle on the 2560×720 canvas. Higher `z` wins where regions overlap (the sheet over the cards,
/// its pills over the sheet). Spec 2026-09-23 §8.7: with a `clip`, only the part of `frame` inside it can be hit.
public struct TouchRegion: Equatable, Sendable {
    public let target: TouchTarget
    public let frame: CGRect
    public let z: Int
    public let clip: CGRect?

    public init(target: TouchTarget, frame: CGRect, z: Int = 0, clip: CGRect? = nil) {
        self.target = target
        self.frame = frame
        self.z = z
        self.clip = clip
    }

    public static func == (lhs: TouchRegion, rhs: TouchRegion) -> Bool {
        lhs.target == rhs.target && same(lhs.frame, rhs.frame) && lhs.z == rhs.z && sameClip(lhs.clip, rhs.clip)
    }

    private static func same(_ a: CGRect, _ b: CGRect) -> Bool {
        a.origin.x == b.origin.x && a.origin.y == b.origin.y && a.size.width == b.size.width && a.size.height == b.size.height
    }

    private static func sameClip(_ a: CGRect?, _ b: CGRect?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (x?, y?): same(x, y)
        default: false
        }
    }
}
