import SwiftUI
import PanelCore

/// Spec 2026-09-07 §2.3: the 520 px middle column — limit rows, TODAY, and the 24 h burn chart.
struct LimitsColumn: View {
    @Environment(\.palette) private var palette
    let state: PanelState

    var body: some View {
        let rows = state.limits.displayRows(now: state.now)
        VStack(alignment: .leading, spacing: 0) {
            Text("Limits").sectionLabel(palette).frame(height: 30, alignment: .leading)
            if rows.isEmpty {
                Text("limits unavailable").font(PanelType.mono(20)).foregroundStyle(palette.muted).padding(.top, 8)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    LimitRowView(row: row, fullBy: state.forecasts[row.id], now: state.now).equatable()
                        .frame(height: 84).padding(.top, i == 0 ? 8 : 0)
                }
            }
            TodayBlock(totals: (state.burn?.fileCount ?? 0) > 0 ? state.todayTotals : nil, today: state.today,
                       sessionCount: state.today?.sessionCount ?? state.allSessions.count, costUSD: state.todayCostUSD)
                .equatable().frame(height: 130).padding(.top, 8)
            BurnChartView(burn: state.burn, chart: state.burnChart, stale: state.burnIsStale).equatable()
                .frame(maxHeight: .infinity).padding(.top, 8)
        }
        .padding(24)
        .frame(width: 520, height: 720, alignment: .topLeading)
        .overlay(alignment: .trailing) { Rectangle().fill(palette.line).frame(width: 1) }
    }
}

/// One limit row (spec §2.3): title and percent, bar, `resets in …` caption with the optional `~full by …`.
/// Spec 2026-09-23 §4.1: a reset under 24 h away counts down to the second in its own `TimelineView`; the rest of the
/// panel changes at most once a minute.
struct LimitRowView: View, Equatable {
    @Environment(\.palette) private var palette
    let row: LimitRow
    let fullBy: Date?
    let now: Date

    static func == (a: LimitRowView, b: LimitRowView) -> Bool { a.row == b.row && a.fullBy == b.fullBy && a.now == b.now }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.title).font(PanelType.mono(20, .bold)).textCase(.uppercase).lineLimit(1)
                Spacer()
                Text("\(row.percent)%").font(PanelType.mono(40, .heavy)).monospacedDigit()
            }
            .frame(height: 40)
            Bar(fraction: Double(row.percent) / 100, color: barColor)
            if let resets = row.resetsAt, resets.timeIntervalSince(now) < 24 * 3600 + 60 {
                TimelineView(.periodic(from: .now, by: 1)) { context in caption(at: context.date) }
            } else {
                caption(at: now)
            }
        }
    }

    /// Accent below 60 %, waiting yellow from 60 %, blocked red from 85 %.
    private var barColor: Color {
        row.percent >= 85 ? ThemePalette.blocked : row.percent >= 60 ? ThemePalette.waiting : palette.accent
    }

    private func caption(at date: Date) -> some View {
        var text = PanelFormat.resetsIn(row.resetsAt, now: date)
        if let full = PanelFormat.fullBy(fullBy, now: date) { text += " · " + full }
        return Text(text).font(PanelType.mono(17)).foregroundStyle(palette.muted).lineLimit(1)
    }
}

/// Plan 4 §4.3 TODAY: says what it counts, four numbers with two-line labels, then sessions · tool calls · cost.
/// Spec 2026-09-23 §4.2: compared by its inputs.
struct TodayBlock: View, Equatable {
    @Environment(\.palette) private var palette
    /// Spec §5: nil (drawn `—`) until a full pass has found at least one transcript.
    let totals: TodayTotals?
    let today: DailyActivity?
    let sessionCount: Int
    let costUSD: Double?

    static func == (a: TodayBlock, b: TodayBlock) -> Bool {
        a.totals == b.totals && a.today == b.today && a.sessionCount == b.sessionCount && a.costUSD == b.costUSD
    }

    var body: some View {
        // Final review: 20 + 4 + (40 + 1 + 20 + 1 + 20) + 4 + 20 = 130, the frame this block is given (§4.3).
        VStack(alignment: .leading, spacing: 4) {
            Text("Today · every session on this Mac").sectionLabel(palette).lineLimit(1)
            HStack(alignment: .top, spacing: 0) {
                stat(totals.map { PanelFormat.compactTokens($0.output) }, "output", "tokens")
                stat(totals.map { PanelFormat.compactTokens($0.input) }, "input", "tokens")
                stat(totals.map { PanelFormat.compactTokens($0.cacheRead) }, "cache", "reads")
                stat(totals.map { PanelFormat.compactTokens($0.messages) }, "messages", " ")
            }
            Text(secondLine).font(PanelType.mono(17)).foregroundStyle(palette.muted).lineLimit(1)
        }
    }

    private func stat(_ value: String?, _ line1: String, _ line2: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value ?? "—").font(PanelType.mono(34, .heavy)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(line1).sectionLabel(palette)
            Text(line2).sectionLabel(palette)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var secondLine: String {
        var parts = ["\(sessionCount) sessions"]
        if let calls = today?.toolCallCount { parts.append("\(PanelFormat.compactTokens(calls)) tool calls") }
        if let cost = costUSD { parts.append(PanelFormat.cost(cost)) }
        return parts.joined(separator: " · ")
    }
}
