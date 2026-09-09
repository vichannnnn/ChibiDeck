import SwiftUI
import PanelCore

/// Character select §4: one row of tiles over the whole canvas, one per theme in tap order, each on its own theme
/// colours; the current one has a 4 pt accent border and plays `top`. The backdrop and the timer live in `PanelView`.
struct CharacterSelect: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let entries = model.themes.map { theme in (theme: theme, mascot: model.mascot(for: theme)) }
        let layout = CharacterSelectLayout(count: entries.count)
        ZStack(alignment: .topLeading) {
            Text("Choose your character").font(PanelType.mono(24, .bold)).foregroundStyle(palette.muted).textCase(.uppercase).tracking(1.5)
                .frame(width: 2432, alignment: .leading).position(x: 1280, y: 48)      // left edge at x 64, centred on y 48
                .allowsHitTesting(false)                                                 // a click on the label falls through to the backdrop
            ForEach(Array(zip(entries, layout.frames)), id: \.0.theme.id) { entry, frame in
                tile(entry.theme, entry.mascot, scale: layout.scale, current: entry.theme.id == model.currentTheme.id)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
            Text("tap a character to choose · tap outside to close").font(PanelType.mono(17)).foregroundStyle(palette.muted)
                .position(x: 1280, y: 640)
                .allowsHitTesting(false)
        }
        .frame(width: 2560, height: 720)
    }

    private func tile(_ theme: Theme, _ mascot: Mascot, scale: Int, current: Bool) -> some View {
        let own = ThemePalette(theme: theme)
        return Button(action: { model.perform(.characterPick(theme.id)) }) {
            VStack(spacing: 0) {
                MascotView(mascot: mascot, pose: current ? .top : .cruise)
                    .frame(width: CGFloat(CharacterSelectLayout.spriteCols * scale), height: CGFloat(CharacterSelectLayout.spriteRows * scale))
                    .padding(.top, CharacterSelectLayout.tilePadding)
                Text(mascot.displayName).font(PanelType.mono(24, .bold)).foregroundStyle(own.text).lineLimit(1)
                    .frame(height: 30).padding(.top, 8)
                Text(theme.name).font(PanelType.mono(17)).foregroundStyle(own.muted).lineLimit(1).minimumScaleFactor(0.8)
                    .frame(height: 22).padding(.bottom, CharacterSelectLayout.tilePadding)
            }
            .padding(.horizontal, CharacterSelectLayout.tilePadding)
            .background(own.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(current ? own.accent : own.line, lineWidth: current ? 4 : 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .touchTarget(.characterPick(theme.id), z: 3)
    }
}
