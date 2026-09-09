import Foundation

public enum ThemeLoader {
    public static func load(_ data: Data) throws -> Theme {
        try JSONDecoder().decode(Theme.self, from: data)
    }
}

public enum ThemeLibrary {
    public static let defaultThemeId = "midnight-witch"

    /// Shipped themes sorted by `order`, then id (spec 2026-09-07 §2.6).
    public static func loadAll() throws -> [Theme] {
        sorted(try PanelResources.urls(extension: "json", subdirectory: "Themes").map { try ThemeLoader.load(try Data(contentsOf: $0)) })
    }

    public static func sorted(_ themes: [Theme]) -> [Theme] {
        themes.sorted { a, b in a.order != b.order ? a.order < b.order : a.id < b.id }
    }

    /// The theme after `id` in cycle order, wrapping; the first theme when `id` is unknown; nil when empty.
    public static func next(after id: String, in themes: [Theme]) -> Theme? {
        let ordered = sorted(themes)
        guard !ordered.isEmpty else { return nil }
        guard let i = ordered.firstIndex(where: { $0.id == id }) else { return ordered[0] }
        return ordered[(i + 1) % ordered.count]
    }
}
