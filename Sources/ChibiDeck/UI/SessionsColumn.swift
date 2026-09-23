import SwiftUI
import PanelCore

/// Spec 2026-09-07 §2.4: the 1640 px right column — `SESSIONS` header with count chips, then the 4×2 card grid.
struct SessionsColumn: View {
    @Environment(\.palette) private var palette
    @Environment(AppModel.self) private var model
    let state: PanelState
    let onTap: (Session) -> Void

    private let columns = Array(repeating: GridItem(.fixed(388), spacing: 16), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 24) {
                Text("Sessions").sectionLabel(palette)
                Text("\(state.allSessions.count) live").font(PanelType.mono(20, .bold)).foregroundStyle(palette.muted)
                ForEach(Array(state.counts.headerLine().enumerated()), id: \.offset) { _, item in
                    Text(item.label).font(PanelType.mono(20, .bold)).foregroundStyle(chipColor(item))
                }
                if state.hiddenByUser > 0 {
                    Text("\(state.hiddenByUser) hidden").font(PanelType.mono(20, .bold)).foregroundStyle(palette.muted)
                }
                Spacer()
                if state.isStale { Chip(text: "stale", color: ThemePalette.blocked) }
            }
            .frame(height: 44)
            .padding(.top, 20)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(state.sessions) { session in
                    SessionCard(input: cardInput(session)) { onTap(session) }.equatable()
                }
            }
            .padding(.top, 16)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(width: 1640, height: 720, alignment: .topLeading)
    }

    private func chipColor(_ item: (label: String, status: SessionStatus)) -> Color {
        if item.label.hasPrefix("+") || item.status == .idle || item.status == .unknown { return palette.muted }
        return ThemePalette.status(item.status)
    }

    /// Spec 2026-09-23 §4.2: the values one card draws, read here so the card's body observes nothing.
    private func cardInput(_ session: Session) -> CardInput {
        CardInput(session: session, detail: state.detail(for: session.sessionId), now: state.now,
                  attention: session.status.needsAttention && !AttentionResolver.isDismissed(session, dismissed: state.dismissed),
                  pill: model.cardPill(for: session), handoffStage: model.handoffStage(for: session))
    }
}
