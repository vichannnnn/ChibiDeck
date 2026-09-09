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
                    LimitRowView(row: row, fullBy: state.forecasts[row.id], now: state.now).frame(height: 84).padding(.top, i == 0 ? 8 : 0)
                }
            }
            TodayBlock(state: state).frame(height: 130).padding(.top, 8)
            BurnChartView(burn: state.burn, chart: state.burnChart, stale: state.burnIsStale).frame(maxHeight: .infinity).padding(.top, 8)
        }
        .padding(24)
        .frame(width: 520, height: 720, alignment: .topLeading)
        .overlay(alignment: .trailing) { Rectangle().fill(palette.line).frame(width: 1) }
    }
}

/// One limit row (spec §2.3): title and percent, bar, `resets in …` caption with the optional `~full by …`.
struct LimitRowView: View {
    @Environment(\.palette) private var palette
    let row: LimitRow
    let fullBy: Date?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.title).font(PanelType.mono(20, .bold)).textCase(.uppercase).lineLimit(1)
                Spacer()
                Text("\(row.percent)%").font(PanelType.mono(40, .heavy)).monospacedDigit()
            }
            .frame(height: 40)
            Bar(fraction: Double(row.percent) / 100, color: barColor)
            Text(caption).font(PanelType.mono(17)).foregroundStyle(palette.muted).lineLimit(1)
        }
    }

    /// Accent below 60 %, waiting yellow from 60 %, blocked red from 85 %.
    private var barColor: Color {
        row.percent >= 85 ? ThemePalette.blocked : row.percent >= 60 ? ThemePalette.waiting : palette.accent
    }

    private var caption: String {
        var text = PanelFormat.resetsIn(row.resetsAt, now: now)
        if let full = PanelFormat.fullBy(fullBy, now: now) { text += " · " + full }
        return text
    }
}

/// Plan 4 §4.3 TODAY: says what it counts, four numbers with two-line labels, then sessions · tool calls · cost.
struct TodayBlock: View {
    @Environment(\.palette) private var palette
    let state: PanelState

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

    /// Spec §5: `—` until a full pass has found at least one transcript.
    private var totals: TodayTotals? { (state.burn?.fileCount ?? 0) > 0 ? state.todayTotals : nil }

    private func stat(_ value: String?, _ line1: String, _ line2: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value ?? "—").font(PanelType.mono(34, .heavy)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(line1).sectionLabel(palette)
            Text(line2).sectionLabel(palette)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var secondLine: String {
        var parts = ["\(state.today?.sessionCount ?? state.allSessions.count) sessions"]
        if let calls = state.today?.toolCallCount { parts.append("\(PanelFormat.compactTokens(calls)) tool calls") }
        if let cost = state.todayCostUSD { parts.append(PanelFormat.cost(cost)) }
        return parts.joined(separator: " · ")
    }
}
