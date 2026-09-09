import SwiftUI
import PanelCore

/// Spec 2026-09-07 §2.4 and Plan 4 §5: one 388×300 card. Rows: status + elapsed, name, repo@branch, `you:`, `claude:`, tasks,
/// context bar with its label, model and effort chips and the answer pill. Waiting cards get the yellow border and glow, blocked cards
/// the red border, unless dismissed. Handoff indicator §A: a card with a running handoff shows `HANDOFF · reply/clear/paste`
/// in the accent with an accent border and no answer pill.
/// Plan 6 §3: a half-second press opens the card menu.
struct SessionCard: View {
    @Environment(\.palette) private var palette
    @Environment(AppModel.self) private var model
    let session: Session
    let detail: SessionDetail
    let now: Date
    let dismissed: Set<DismissKey>
    let onTap: () -> Void

    private var statusColor: Color { ThemePalette.status(session.status) }
    private var isDim: Bool { session.status == .idle || session.status == .unknown }
    /// Spec 2026-09-06 §6.3: an acknowledged session keeps its status colour but loses the glow and the attention border.
    private var attention: Bool { session.status.needsAttention && !AttentionResolver.isDismissed(session, dismissed: dismissed) }

    /// Plan 4 §5.3: `Allow ↵`, `N opts ›` or the first quick reply, only while an answer could be typed.
    private var cardPill: AnswerResolver.CardPill? { model.cardPill(for: session) }
    /// Handoff indicator §A: set from the tap until the paste lands or the sequence fails.
    private var handoffStage: HandoffStage? { model.handoffStage(for: session) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    if let stage = handoffStage, session.status != .waiting {        // Handoff indicator §A; a waiting session keeps its row (Handoff §4: the user answers the prompt)
                        Circle().fill(palette.accent).frame(width: 12, height: 12)
                        Text("HANDOFF").font(PanelType.mono(20, .bold)).foregroundStyle(palette.accent)
                        Text(stage.label).font(PanelType.mono(17)).foregroundStyle(palette.accent).lineLimit(1)
                    } else {
                        Circle().fill(statusColor).frame(width: 12, height: 12)
                        Text(statusWord).font(PanelType.mono(20, .bold)).foregroundStyle(isDim ? palette.muted : statusColor)
                        if session.status == .waiting, let reason = session.waitingFor {
                            Text("· \(reason)").font(PanelType.mono(17)).foregroundStyle(palette.muted).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(PanelFormat.elapsedShort(session.elapsed(at: now))).font(PanelType.mono(17)).foregroundStyle(palette.muted)
                }
                .frame(height: 26)
                Text(session.name).font(PanelType.mono(26, .bold)).lineLimit(1).truncationMode(.tail).padding(.top, 6)
                Text(repoLine).font(PanelType.mono(17)).foregroundStyle(palette.muted).lineLimit(1).padding(.top, 2)
                promptLine("you:", detail.lastUserPrompt).padding(.top, 10)
                promptLine("claude:", detail.lastAssistantText).padding(.top, 4)
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
                    if let pill = cardPill, handoffStage == nil || session.status == .waiting {   // Handoff indicator §A: no quick replies mid-handoff; a prompt's Allow stays
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
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: handoffStage != nil ? 2 : attention ? 3 : 2))
            .shadow(color: attention && session.status == .waiting ? ThemePalette.waiting.opacity(0.3) : .clear, radius: 24)
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

    private func promptLine(_ prefix: String, _ text: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(prefix).font(PanelType.mono(20)).foregroundStyle(palette.muted)
            Text(text ?? "—").font(PanelType.mono(20)).lineLimit(1).truncationMode(.tail)
        }
    }

    private var borderColor: Color {
        if handoffStage != nil { return palette.accent }                               // Handoff indicator §A
        return switch session.status {
        case .waiting where attention: ThemePalette.waiting
        case .blocked where attention: ThemePalette.blocked
        default: palette.line
        }
    }
}
