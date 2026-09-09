import SwiftUI
import PanelCore

/// Spec 2026-09-07 §2: 400 px left column, 520 px limits column, 1640 px sessions column (the sheet slides over the last).
/// Plan 3 §5.3: the root declares the canvas coordinate space and collects every `.touchTarget` region.
/// Plan 6 §4: the card menu layer sits over the whole canvas (backdrop z 2, rows z 3); Character select §4: so does the character select (backdrop z 2, tiles z 3).
struct PanelView: View {
    @Environment(AppModel.self) private var model
    static let coordinateSpace = "panel"

    var body: some View {
        let state = model.collector.state
        let palette = ThemePalette(theme: model.currentTheme)
        HStack(spacing: 0) {
            LeftColumn(state: state)
            HStack(spacing: 0) {
                LimitsColumn(state: state)
                ZStack(alignment: .topLeading) {
                    SessionsColumn(state: state) { session in model.perform(.card(session.sessionId)) }
                    if let id = model.ui.selectedSessionId, let session = state.session(id: id) {
                        DetailSheet(session: session, detail: state.detail(for: id), now: state.now)
                    }
                }
                .frame(width: 1640, height: 720)
                .animation(.easeInOut(duration: 0.25), value: model.ui.selectedSessionId)
            }
            .opacity(model.ui.isDimmed ? 0.15 : 1)      // spec §2.8: the middle and right columns fade, the left stays
        }
        .frame(width: 2560, height: 720)
        .overlay(alignment: .topLeading) {                                   // Plan 6 §4–5: the card menu layer
            if let id = model.ui.menuSessionId, let session = state.session(id: id),
               let card = model.touchRegions.first(where: { $0.target == .card(id) })?.frame {
                ZStack(alignment: .topLeading) {
                    Color.clear.contentShape(Rectangle()).frame(width: 2560, height: 720)
                        .onTapGesture { model.perform(.menuClose) }
                        .touchTarget(.menuClose, z: 2)
                    CardMenu(session: session).position(x: card.midX, y: min(card.midY, 720 - CardMenu.height / 2 - 8))   // Handoff §3: four rows now; keep it on the canvas
                }
            }
            if model.ui.characterSelectOpenedAt != nil {                                   // Character select §4: the screen over the whole canvas
                ZStack(alignment: .topLeading) {
                    palette.background.opacity(0.92).frame(width: 2560, height: 720)
                        .onTapGesture { model.perform(.characterSelectClose) }
                        .touchTarget(.characterSelectClose, z: 2)
                    CharacterSelect()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.ui.characterSelectOpenedAt != nil)
        .coordinateSpace(name: Self.coordinateSpace)
        .onPreferenceChange(TouchRegionKey.self) { regions in
            MainActor.assumeIsolated { model.touchRegions = regions }
        }
        .background(palette.background)
        .foregroundStyle(palette.text)
        .environment(\.palette, palette)
        .animation(.easeInOut(duration: 0.3), value: model.currentTheme.id)
        .overlay(alignment: .bottom) {
            if let toast = model.ui.toast {
                Text(toast).font(PanelType.mono(24, .bold)).padding(.horizontal, 28).padding(.vertical, 14)
                    .background(palette.card).clipShape(Capsule()).overlay(Capsule().stroke(palette.line, lineWidth: 2))
                    .padding(.bottom, 24).transition(.opacity)
                    .task(id: model.ui.toast) {
                        let displayedToast = model.ui.toast
                        try? await Task.sleep(for: .seconds(2))
                        if model.ui.toast == displayedToast { model.ui.toast = nil }
                    }
            }
        }
        .task(id: model.ui.sheetOpenedAt) {
            guard model.ui.sheetOpenedAt != nil else { return }
            try? await Task.sleep(for: .seconds(model.settings.sheetTimeoutSeconds))
            guard !Task.isCancelled else { return }
            model.closeSheet()
        }
        .task(id: model.ui.menuOpenedAt) {                                   // Plan 6 §5: the menu closes itself after 6 s
            guard model.ui.menuOpenedAt != nil else { return }
            try? await Task.sleep(for: .seconds(AppModel.menuTimeout))
            guard !Task.isCancelled else { return }
            model.closeMenu()
        }
        .task(id: model.ui.characterSelectOpenedAt) {                            // Character select §6: closes itself after 10 s
            guard model.ui.characterSelectOpenedAt != nil else { return }
            try? await Task.sleep(for: .seconds(AppModel.characterSelectTimeout))
            guard !Task.isCancelled else { return }
            model.closeCharacterSelect()
        }
        .onChange(of: state.allSessions.map(\.sessionId)) { _, ids in
            if let id = model.ui.selectedSessionId, !ids.contains(id) { model.closeSheet() }
        }
        .onChange(of: state.sessions.map(\.sessionId)) { _, ids in                 // Plan 6 §5: the card left the grid (exited, hidden, or sorted past the eighth slot)
            if let id = model.ui.menuSessionId, !ids.contains(id) { model.closeMenu() }
        }
        .task(id: dimKey) {
            while !Task.isCancelled {
                let now = Date()
                let dim = AutoDimPolicy.shouldDim(enabled: model.settings.autoDimEnabled, lastTouch: model.ui.lastTouch,
                                                  lastStateChange: model.collector.lastStateChange, now: now, quietMinutes: model.settings.autoDimMinutes)
                if dim != model.ui.isDimmed { withAnimation(.easeInOut(duration: 1.2)) { model.ui.isDimmed = dim } }
                let wait = dim ? 5 : AutoDimPolicy.nextCheck(lastTouch: model.ui.lastTouch, lastStateChange: model.collector.lastStateChange, now: now, quietMinutes: model.settings.autoDimMinutes)
                try? await Task.sleep(for: .seconds(wait))
            }
        }
    }

    /// Any of these changing restarts the dim countdown.
    private var dimKey: String {
        "\(model.settings.autoDimEnabled)-\(model.settings.autoDimMinutes)-\(model.ui.lastTouch?.timeIntervalSince1970 ?? 0)-\(model.collector.lastStateChange.timeIntervalSince1970)"
    }
}
