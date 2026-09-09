import AppKit
import SwiftUI

/// Spec 2026-09-07 §2.1: everything on the panel is SF Mono, and nothing is smaller than 17 pt.
enum PanelType {
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: max(17, size), weight: weight, design: .monospaced)
    }

    /// The advance of one glyph of the monospaced system font at `size`, measured once per size (SF Mono is 0.618 em,
    /// not 0.6). The sheet's pager divides its width by this; a guessed advance drops a line from most pages (Plan 4 §6.1).
    static func monoAdvance(_ size: CGFloat) -> CGFloat {
        if let cached = advances[size] { return cached }
        let width = ("M" as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: size, weight: .regular)]).width
        advances[size] = width
        return width
    }

    /// Measured advances, keyed by point size. Main-thread UI code only (the app target is Swift 5).
    private static var advances: [CGFloat: CGFloat] = [:]
}

extension View {
    /// Section label (`LIMITS`, `TODAY`, `24 H BURN`, `SESSIONS`): 17 pt semibold, uppercase, tracked, muted.
    func sectionLabel(_ palette: ThemePalette) -> some View {
        font(PanelType.mono(17, .semibold)).foregroundStyle(palette.muted).textCase(.uppercase).tracking(1.5)
    }
}

/// Spec §2.1 chip: 18 pt semibold muted text on the theme `line` colour, radius 6, 8 pt side padding.
struct Chip: View {
    @Environment(\.palette) private var palette
    let text: String
    var color: Color? = nil

    var body: some View {
        Text(text).font(PanelType.mono(18, .semibold)).foregroundStyle(color ?? palette.muted).lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(palette.line).clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

/// A horizontal progress bar: track in `line`, fill in `color`, `fraction` clamped to 0…1.
struct Bar: View {
    @Environment(\.palette) private var palette
    let fraction: Double
    let color: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2).fill(palette.line)
                RoundedRectangle(cornerRadius: height / 2).fill(color)
                    .frame(width: geo.size.width * CGFloat(min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
    }
}
