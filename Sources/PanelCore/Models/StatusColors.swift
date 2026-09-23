import Foundation

/// Spec 2026-09-23 §6 (amends 2026-09-06 §4.2): the theme-independent status colours, as hex. `ThemePalette` draws
/// them; `ThemeLoaderTests` keeps every theme accent apart from them. Idle is drawn in the theme accent and unknown in
/// the theme's muted text, so neither is listed.
public enum StatusColors {
    public static let waiting = "#F5C542"
    public static let busy = "#7DE3A5"
    public static let blocked = "#FF8C9A"
    /// Grey since 2026-09-23; the lavender `#C6B5FF` it replaced sat on three theme accents.
    public static let shell = "#8E97AB"
    /// A context window at 80 % or more.
    public static let hot = "#FF9A5A"

    /// The colours that carry a meaning, named for test messages.
    public static let reserved: [(name: String, hex: String)] = [
        ("waiting", waiting), ("blocked", blocked), ("busy", busy), ("shell", shell), ("hot", hot),
    ]
}
