import SwiftUI
import PanelCore

extension Color {
    init(rgb: RGB) { self.init(red: rgb.r, green: rgb.g, blue: rgb.b) }
    init(hex: String, fallback: Color = .black) {
        if let c = RGB(hex: hex) { self.init(rgb: c) } else { self = fallback }
    }
}

struct ThemePalette: Equatable {
    let background: Color
    let card: Color
    let line: Color
    let accent: Color
    let text: Color
    let muted: Color

    static let waiting = Color(hex: "#F5C542")
    static let busy = Color(hex: "#7DE3A5")
    static let blocked = Color(hex: "#FF8C9A")
    static let shell = Color(hex: "#C6B5FF")
    static let idle = Color(hex: "#4A4866")
    static let hot = Color(hex: "#FF9A5A")

    init(theme: Theme) {
        background = Color(hex: theme.background)
        card = Color(hex: theme.card)
        line = Color(hex: theme.line)
        accent = Color(hex: theme.accent)
        text = Color(hex: theme.text, fallback: .white)
        muted = Color(hex: theme.muted, fallback: .gray)
    }

    static func status(_ s: SessionStatus) -> Color {
        switch s {
        case .waiting: waiting
        case .busy: busy
        case .blocked: blocked
        case .shell: shell
        case .idle, .unknown: idle
        }
    }

    static let fallback = ThemePalette(theme: Theme(id: "midnight-witch", name: "Midnight Witch", mascot: "mage", order: 0, background: "#0C0D17",
                                                    card: "#151729", line: "#23263D", accent: "#B3A6EA", text: "#E8E7F3", muted: "#A09FBF"))
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = ThemePalette.fallback
}

extension EnvironmentValues {
    var palette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}
