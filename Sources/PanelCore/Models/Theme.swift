import Foundation

public struct Theme: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let name: String
    public let mascot: String
    /// Spec 2026-09-07 §2.6: the tap-to-cycle order. Required; `ThemeLibrary` sorts by it.
    public let order: Int
    public let background: String
    public let card: String
    public let line: String
    public let accent: String
    public let text: String
    public let muted: String

    public init(id: String, name: String, mascot: String, order: Int, background: String, card: String, line: String, accent: String, text: String, muted: String) {
        self.id = id; self.name = name; self.mascot = mascot; self.order = order; self.background = background; self.card = card
        self.line = line; self.accent = accent; self.text = text; self.muted = muted
    }
}
