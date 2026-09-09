import SwiftUI
import PanelCore

/// Spec 2026-09-07 §2.5 and Plan 4 §6: the sheet in the monospaced type, `context 527k / 1M` over a hairline, the Claude text paged
/// with ▲ ▼, and background agents reading their text from the job file. Plan 3 §5.3–5.4: every button goes through
/// `AppModel.perform`, the whole sheet is the `.sheetBackdrop` region (z 1) and the pills sit above it (z 2); Plan 4 §6.2:
/// the answers row above Focus tab · Dismiss; background agents get `no channel`.
struct DetailSheet: View {
    /// Plan 4 §6.1: the Claude text box is 7 lines of the 26 pt monospaced type.
    static let rows = 7
    static let lineHeight: CGFloat = 32
    /// The ▲ ▼ column beside the text box, and the gap between them: the pager subtracts both from its width.
    static let pillColumn: CGFloat = 80
    static let pillGap: CGFloat = 16

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    /// Sheet swipe §B: when the current mouse drag began, for the one-second rule.
    @State private var dragStart: Date?
    let session: Session
    let detail: SessionDetail
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 18) {
                pill("‹ Back", target: .sheetBack, background: palette.line, foreground: palette.text)
                Text(session.name).font(PanelType.mono(44, .heavy)).tracking(-1).lineLimit(1).minimumScaleFactor(0.6)
                statusPill
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text("context \(PanelFormat.contextLabel(used: detail.contextUsedTokens, size: detail.contextWindowSize))")
                        .font(PanelType.mono(26, .bold))
                    Bar(fraction: (detail.contextPercent ?? 0) / 100,
                        color: (detail.contextPercent ?? 0) >= 80 ? ThemePalette.hot : palette.accent, height: 6)
                        .frame(width: 260)
                }
            }
            Text(metaLine).font(PanelType.mono(22)).foregroundStyle(palette.muted).lineLimit(1).padding(.top, 6)
            HStack(alignment: .top, spacing: 30) {
                VStack(alignment: .leading, spacing: 6) {
                    label("You said")
                    Text(youSaid).font(PanelType.mono(26)).foregroundStyle(palette.text.opacity(0.85)).lineLimit(2)
                    label(session.status == .waiting ? "Claude asked" : "Claude said").padding(.top, 8)
                    GeometryReader { geo in
                        // Plan 4 §6.1: the advance is measured from the font, and `Int(…)` floors it deliberately —
                        // one column too many wraps a pager line in two and pushes its tail off the page.
                        let columns = max(1, Int((geo.size.width - Self.pillColumn - Self.pillGap) / PanelType.monoAdvance(26)))
                        let pages = TextPager.pages(detail.lastAssistantText ?? "—", columns: columns, rows: Self.rows)
                        let page = min(model.ui.sheetPage, pages.count - 1)
                        HStack(alignment: .top, spacing: Self.pillGap) {
                            Text(pages[page]).font(PanelType.mono(26)).lineLimit(Self.rows)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            VStack(spacing: 8) {
                                pill("▲", target: .sheetPageUp, background: palette.line, foreground: palette.text, enabled: page > 0, compact: true)
                                Text("\(page + 1)/\(pages.count)").font(PanelType.mono(20)).foregroundStyle(palette.muted).monospacedDigit()
                                pill("▼", target: .sheetPageDown, background: palette.line, foreground: palette.text, enabled: page < pages.count - 1, compact: true)
                            }
                            .frame(width: Self.pillColumn)
                        }
                        .onChange(of: pages.count, initial: true) { _, count in
                            model.ui.sheetPage = min(model.ui.sheetPage, count - 1)      // Plan 4 §6.1: the stored index is clamped when the text changes
                        }
                    }
                    .frame(height: CGFloat(Self.rows) * Self.lineHeight)
                    .layoutPriority(1)          // if the sheet ever runs short, "You said" compresses, never the paged box
                    if let suggested = detail.suggestedReply {
                        Text("suggested: \(suggested)").font(PanelType.mono(20)).foregroundStyle(palette.accent).lineLimit(1).padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                if !detail.tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        label("Tasks · \(detail.tasks.filter { $0.status == .completed }.count) of \(detail.tasks.count) done")
                        ForEach(detail.tasks.prefix(6)) { task in
                            HStack(spacing: 14) {
                                Text(task.status == .completed ? "✓" : task.status == .inProgress ? "▶" : "○")
                                    .font(PanelType.mono(22, .heavy)).frame(width: 26)
                                    .foregroundStyle(task.status == .completed ? ThemePalette.busy : task.status == .inProgress ? ThemePalette.waiting : palette.muted)
                                Text(task.subject).font(PanelType.mono(22)).lineLimit(1)
                                    .foregroundStyle(task.status == .completed ? palette.muted : palette.text)
                            }
                        }
                    }
                    .frame(width: 620, alignment: .topLeading)
                }
            }
            .padding(.top, 12)
            Spacer(minLength: 0)
            if session.status == .waiting, let pending = detail.pending {                 // information even when the panel cannot answer (final review)
                Text(pendingLine(pending)).font(PanelType.mono(20)).foregroundStyle(palette.muted).lineLimit(1).padding(.top, 10)
            }
            HStack(spacing: 12) {
                ForEach(Array(answers.enumerated()), id: \.offset) { index, answer in
                    pill(Self.cut(answer.label), target: .sheetAnswer(index), background: palette.accent, foreground: palette.background, compact: true)
                }
                if session.kind == .background {
                    Text("no channel").font(PanelType.mono(17)).foregroundStyle(palette.muted)
                }
            }
            .frame(height: answers.isEmpty && session.kind != .background ? 0 : 48)
            .padding(.top, answers.isEmpty && session.kind != .background ? 0 : 8)
            HStack(alignment: .top, spacing: 16) {
                pill("Focus tab", target: .sheetFocus, background: palette.line, foreground: palette.text, enabled: canFocus)
                pill("Handoff", target: .sheetHandoff, background: palette.line, foreground: palette.text, enabled: model.canHandoff(session))
                if let stage = model.handoffStage(for: session) {                   // Handoff indicator §A
                    Text("HANDOFF \(stage.label)").font(PanelType.mono(20, .bold)).foregroundStyle(palette.accent).padding(.top, 20)
                }
                pill("Dismiss", target: .sheetDismiss, background: palette.line, foreground: palette.text)
                pill("Hide", target: .sheetHide, background: palette.line, foreground: palette.text)
                Spacer()
                Text("back to tiles in \(secondsLeft) s").font(PanelType.mono(20, .bold)).foregroundStyle(palette.muted).textCase(.uppercase).tracking(1.5)
                    .padding(.top, 20)
            }
            .padding(.top, 8)
        }
        .padding(EdgeInsets(top: 28, leading: 34, bottom: 28, trailing: 34))
        .frame(width: 1600, height: 680)
        .background(palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(session.status == .waiting ? ThemePalette.waiting : palette.line, lineWidth: 3))
        .padding(20)
        .frame(width: 1640, height: 720)
        .background(palette.background)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { model.perform(.sheetBackdrop) })
        .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { drag in        // Sheet swipe §B: the mouse path, same rule in points
            let t = drag.translation
            if let direction = SwipeRecognizer.classify(dx: Int(t.width), dy: Int(t.height), duration: drag.time.timeIntervalSince(dragStart ?? drag.time),
                                                         minTravel: Int(SwipeRecognizer.minTravelPoints)),
               let action = SwipePaging.target(for: direction, over: .sheetBackdrop) {
                model.perform(action)
            }
            dragStart = nil
        }.onChanged { drag in if dragStart == nil { dragStart = drag.time } })
        .touchTarget(.sheetBackdrop, z: 1)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private var canAnswer: Bool { ActionAvailability.canAnswer(session, actionsAvailable: model.actions.isAvailable) }
    private var answers: [Answer] { canAnswer ? model.answers(for: session) : [] }

    private func pendingLine(_ pending: PendingInput) -> String {
        switch pending {
        case .permission(_, let summary): return "wants to run · \(summary)"
        case .question(let text, _): return "asks · \(text)"
        }
    }

    /// Option labels can be sentences; a pill shows at most 22 characters.
    static func cut(_ s: String, to limit: Int = 22) -> String {
        s.count > limit ? String(s.prefix(limit - 1)) + "…" : s
    }

    private var canFocus: Bool { ActionAvailability.canFocus(session, actionsAvailable: model.actions.isAvailable) }

    private var secondsLeft: Int {
        guard let opened = model.ui.sheetOpenedAt else { return 0 }
        return max(0, model.settings.sheetTimeoutSeconds - Int(now.timeIntervalSince(opened)))
    }

    /// `no transcript` only when neither the transcript nor the job file gave any text (spec §2.5).
    private var youSaid: String {
        if let prompt = detail.lastUserPrompt { return "\u{201C}\(prompt)\u{201D}" }
        return detail.lastAssistantText == nil ? "no transcript" : "—"
    }

    private var statusPill: some View {
        let text = session.status == .waiting ? "WAITING · \(session.waitingFor ?? "input needed")" : session.status.rawValue.uppercased()
        let color = ThemePalette.status(session.status)
        return Text(text).font(PanelType.mono(24, .bold)).padding(.horizontal, 18).padding(.vertical, 8)
            .background(session.status == .waiting ? ThemePalette.waiting : color.opacity(0.2))
            .foregroundStyle(session.status == .waiting ? Color(hex: "#1A1400") : color)
            .clipShape(Capsule())
    }

    private var metaLine: String {
        var parts = [PanelFormat.modelLabel(detail.modelName)]
        if let effort = detail.effort { parts.append(effort) }                       // Plan 4 §5.1: `Fable 5.1 · max · 9h 11m · …`
        parts += [PanelFormat.elapsed(session.elapsed(at: now)), PanelFormat.homeRelative(session.cwd, home: ClaudePaths.home.path)]
        if session.kind == .background { parts.append("background · \(detail.jobState ?? session.status.rawValue)") }
        if let b = detail.branch { parts.append(b) }
        if let c = detail.costUSD { parts.append("\(PanelFormat.cost(c)) today") }
        return parts.joined(separator: " · ")
    }

    private func label(_ s: String) -> some View {
        Text(s).font(PanelType.mono(20, .bold)).foregroundStyle(palette.muted).textCase(.uppercase).tracking(2)
    }

    /// A sheet button: the click and the Edge tap both end in `model.perform(target)`. Plan 4 §8.1: a disabled pill
    /// registers no touch region. `compact` is the answer-row and ▲ ▼ size.
    private func pill(_ title: String, target: TouchTarget, background: Color, foreground: Color, enabled: Bool = true, compact: Bool = false) -> some View {
        Button(action: { model.perform(target) }) {
            Text(title).font(PanelType.mono(compact ? 22 : 28, .bold)).lineLimit(1)
                .padding(.horizontal, compact ? 18 : 34).padding(.vertical, compact ? 10 : 12)
                .background(background).foregroundStyle(foreground).clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .touchTarget(target, z: 2, when: enabled)
    }
}
