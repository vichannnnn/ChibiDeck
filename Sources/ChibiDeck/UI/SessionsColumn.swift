import SwiftUI
import PanelCore

/// Spec 2026-09-07 §2.4: the 1640 px right column — `SESSIONS` header with count chips, then the card grid.
/// Spec 2026-09-23 §8: every session, four to a row, in a two-row viewport scrolled by `PanelUIState.gridOffset`; the
/// header counts what is scrolled out of view, and a card outside the viewport cannot be tapped.
struct SessionsColumn: View {
    @Environment(\.palette) private var palette
    @Environment(AppModel.self) private var model
    let state: PanelState
    let onTap: (Session) -> Void

    private let columns = Array(repeating: GridItem(.fixed(388), spacing: 16), count: GridScroll.columns)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(height: 44)
                .padding(.top, 20)
            viewport
                .padding(.top, 16)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(width: 1640, height: 720, alignment: .topLeading)
    }

    private var header: some View {
        let offset = model.ui.gridOffset, count = state.sessions.count
        let above = GridScroll.above(offset: offset, count: count), below = GridScroll.below(offset: offset, count: count)
        return HStack(spacing: 24) {
            Text("Sessions").sectionLabel(palette)
            Text("\(state.allSessions.count) live").font(PanelType.mono(20, .bold)).foregroundStyle(palette.muted)
            ForEach(Array(state.counts.headerLine().enumerated()), id: \.offset) { _, item in
                Text(item.label).font(PanelType.mono(20, .bold)).foregroundStyle(chipColor(item.status))
            }
            if state.hiddenByUser > 0 {
                Text("\(state.hiddenByUser) hidden").font(PanelType.mono(20, .bold)).foregroundStyle(palette.muted)
            }
            if above > 0 {                                                        // spec 2026-09-23 §8.5
                let urgent = GridScroll.attentionAbove(offset: offset, sessions: state.sessions, dismissed: state.dismissed)
                Text("\(above) above ▲").font(PanelType.mono(20, .bold)).foregroundStyle(urgent ? ThemePalette.waiting : palette.muted)
            }
            if below > 0 {
                Text("\(below) below ▼").font(PanelType.mono(20, .bold)).foregroundStyle(palette.muted)
            }
            Spacer()
            if state.isStale { Chip(text: "stale", color: ThemePalette.blocked) }
        }
    }

    /// Spec 2026-09-23 §8.2, §8.7: the grid is offset inside a clipped two-row viewport; every region registered inside
    /// is clipped to it. The viewport itself is the `.sessionsGrid` region, under the cards (z −1).
    private var viewport: some View {
        GeometryReader { geo in
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(state.sessions) { session in
                    SessionCard(input: cardInput(session)) { onTap(session) }.equatable()
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .offset(y: -model.ui.gridOffset)
            .environment(\.touchClip, geo.frame(in: .named(PanelView.coordinateSpace)))
        }
        .frame(width: 1600, height: GridScroll.viewportHeight, alignment: .topLeading)
        .clipped()
        .contentShape(Rectangle())
        .touchTarget(.sessionsGrid, z: -1)
        .simultaneousGesture(mouseDrag)
    }

    /// Spec 2026-09-23 §8.4: click-drag in the preview makes the same calls as a finger.
    private var mouseDrag: some Gesture {
        DragGesture(minimumDistance: ScrollDragRecognizer.minTravelPoints, coordinateSpace: .named(PanelView.coordinateSpace))
            .onChanged { drag in
                if model.ui.gridDragStart == nil { model.beginGridDrag() }
                model.dragGrid(travel: drag.translation.height)
            }
            .onEnded { drag in model.endGridDrag(speed: drag.velocity.height) }
    }

    /// Spec 2026-09-23 §4.2: the values one card draws, read here so the card's body observes nothing.
    private func cardInput(_ session: Session) -> CardInput {
        CardInput(session: session, detail: state.detail(for: session.sessionId), now: state.now,
                  attention: session.status.needsAttention && !AttentionResolver.isDismissed(session, dismissed: state.dismissed),
                  pill: model.cardPill(for: session), handoffStage: model.handoffStage(for: session))
    }

    /// Spec 2026-09-23 §7: waiting, blocked and idle in their colours; busy, shell and unknown muted.
    private func chipColor(_ status: SessionStatus) -> Color {
        status == .waiting || status == .blocked || status == .idle ? palette.statusColor(status) : palette.muted
    }
}
