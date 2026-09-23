import SwiftUI
import PanelCore

/// Spec 2026-09-23 §4.2: everything one card draws, compared by value, so a card redraws only when its own session,
/// detail, pill or handoff stage changes. `SessionsColumn` builds it; the card reads nothing from `AppModel` in `body`.
struct CardInput: Equatable {
    let session: Session
    let detail: SessionDetail
    let now: Date
    /// Waiting or blocked, and not dismissed (spec 2026-09-06 §6.3).
    let attention: Bool
    let pill: AnswerResolver.CardPill?
    let handoffStage: HandoffStage?
}

/// Spec 2026-09-07 §2.4, Plan 4 §5 and spec 2026-09-23 §3.2, §7: one 388×300 card. Rows: status + elapsed, title (up to two
/// lines), repo@branch, `claude:` (two lines, one with a tasks line), tasks, context bar with its label, model and effort
/// chips and the answer pill. Colour marks what waits for the user (waiting, blocked, idle); work in progress stays quiet.
/// Waiting cards get the yellow border and glow, blocked cards the red border, unless dismissed. Handoff indicator §A:
/// a card with a running handoff shows `HANDOFF · reply/clear/paste` in the accent with an accent border and no answer pill.
/// Plan 6 §3: a half-second press opens the card menu.
struct SessionCard: View, Equatable {
    @Environment(\.palette) private var palette
    @Environment(AppModel.self) private var model
    let input: CardInput
    let onTap: () -> Void

    static func == (a: SessionCard, b: SessionCard) -> Bool { a.input == b.input }

    private var session: Session { input.session }
    private var detail: SessionDetail { input.detail }
    private var statusColor: Color { palette.statusColor(session.status) }
    /// Spec 2026-09-23 §7: only an unknown session dims; idle waits for the user's next message.
    private var isDim: Bool { session.status == .unknown }
    /// Spec 2026-09-23 §7: the statuses drawn in colour and bold.
    private var isLoud: Bool { session.status == .waiting || session.status == .blocked || session.status == .idle }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    if let stage = input.handoffStage, session.status != .waiting {   // Handoff indicator §A; a waiting session keeps its row (Handoff §4)
                        Circle().fill(palette.accent).frame(width: 12, height: 12)
                        Text("HANDOFF").font(PanelType.mono(20, .bold)).foregroundStyle(palette.accent)
                        Text(stage.label).font(PanelType.mono(17)).foregroundStyle(palette.accent).lineLimit(1)
                    } else {
                        Circle().fill(statusColor).frame(width: 12, height: 12)
                        Text(statusWord).font(PanelType.mono(20, isLoud ? .bold : .regular)).foregroundStyle(isLoud ? statusColor : palette.muted)
                        if session.status == .waiting, let reason = session.waitingFor {
                            Text("· \(reason)").font(PanelType.mono(17)).foregroundStyle(palette.muted).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(PanelFormat.elapsedShort(session.elapsed(at: input.now))).font(PanelType.mono(17)).foregroundStyle(palette.muted)
                }
                .frame(height: 26)
                Text(detail.title ?? session.name).font(PanelType.mono(24, .bold)).lineLimit(2).truncationMode(.tail)   // spec 2026-09-23 §3.2
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 6)
                Text(repoLine).font(PanelType.mono(17)).foregroundStyle(palette.muted).lineLimit(1).padding(.top, 2)
                claudeLine.padding(.top, 10)
                Spacer(minLength: 0)
                if !detail.tasks.isEmpty {
                    Text(tasksLine).font(PanelType.mono(17)).foregroundStyle(palette.muted).lineLimit(1).padding(.bottom, 8)
                }
                HStack(spacing: 8) {
                    Bar(fraction: (detail.contextPercent ?? 0) / 100,
                        color: (detail.contextPercent ?? 0) >= 80 ? ThemePalette.hot : palette.accent, height: 10)
                    Text(PanelFormat.contextLabel(used: detail.contextUsedTokens, size: detail.contextWindowSize))
                        .font(PanelType.mono(20)).foregroundStyle(palette.muted).lineLimit(1).fixedSize()
                }
                .padding(.top, 8)
                // Plan 4 §5.1: 116 + 83 + 121 + three 6 pt gaps = 338 of 348 pt in the widest case (medium · 3 opts ›)
                HStack(spacing: 6) {
                    Chip(text: PanelFormat.modelLabel(detail.modelName))
                    if let effort = detail.effort {
                        Chip(text: effort)                                    // Plan 4 §5.1: the session's effort level
                    }
                    Spacer(minLength: 0)
                    if let pill = input.pill, input.handoffStage == nil || session.status == .waiting {   // Handoff indicator §A: no quick replies mid-handoff; a prompt's Allow stays
                        Button(action: { model.perform(pill.opensSheet ? .card(session.sessionId) : .cardAnswer(session.sessionId)) }) {
                            // Plan 4 §5.3: theme accent, 2 pt lower than the chip row; the 6 pt pad keeps the touch region ≈ 43 pt tall.
                            Text(pill.label).font(PanelType.mono(18, .bold)).lineLimit(1).padding(.horizontal, 16).padding(.vertical, 8)
                                .background(palette.accent).foregroundStyle(palette.background).clipShape(Capsule())
                                .offset(y: 2)
                                .padding(.top, 6)
                        }
                        .buttonStyle(.plain)
                        .layoutPriority(1)
                        .touchTarget(.cardAnswer(session.sessionId), z: 1, when: !pill.opensSheet)
                    }
                }
                .padding(.top, 8)
            }
            .padding(20)
            .frame(width: 388, height: 300, alignment: .topLeading)
            .foregroundStyle(isDim ? palette.muted : palette.text)
            .background(palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: input.handoffStage != nil ? 2 : input.attention ? 3 : 2))
            .shadow(color: input.attention && session.status == .waiting ? ThemePalette.waiting.opacity(0.3) : .clear, radius: 24)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(LongPressGesture(minimumDuration: LongPressRecognizer.minimumDuration)
            .onEnded { _ in model.perform(.cardMenu(session.sessionId)) })       // Plan 6 §3: the mouse path in the preview window; the release's click is ignored while the menu is open
        .touchTarget(.card(session.sessionId))
    }

    private var statusWord: String {
        switch session.status {
        case .waiting: "WAITING"
        case .blocked: "BLOCKED"
        case .busy: "WORKING"
        case .shell: "SHELL"
        case .idle: "IDLE"
        case .unknown: "?"
        }
    }

    /// Last path component of the working directory, `@branch` when known.
    private var repoLine: String {
        let repo = URL(fileURLWithPath: session.cwd).lastPathComponent
        return detail.branch.map { "\(repo)@\($0)" } ?? repo
    }

    private var tasksLine: String {
        let done = detail.tasks.filter { $0.status == .completed }.count
        var line = "tasks \(done)/\(detail.tasks.count)"
        if let active = detail.tasks.first(where: { $0.status == .inProgress }) { line += " · ▶ \(active.subject)" }
        return line
    }

    /// Spec 2026-09-23 §3.2: the prefix runs inline so the message wraps under it across the card; two lines, one while
    /// the tasks line shows (260 pt: 248 without it, 253 with it). `you:` lives on the sheet.
    private var claudeLine: some View {
        (Text("claude: ").foregroundStyle(palette.muted) + Text(detail.lastAssistantText.map(PanelFormat.singleLine) ?? "—"))
            .font(PanelType.mono(20)).lineLimit(detail.tasks.isEmpty ? 2 : 1).truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var borderColor: Color {
        if input.handoffStage != nil { return palette.accent }                         // Handoff indicator §A
        return switch session.status {
        case .waiting where input.attention: ThemePalette.waiting
        case .blocked where input.attention: ThemePalette.blocked
        default: palette.line
        }
    }
}
