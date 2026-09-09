import SwiftUI
import PanelCore

/// Plan 4 §4.4: `TOKENS BURNED PER HOUR · 24 H`, a 64 pt gutter with three token labels, 24 hourly bars (the current
/// hour in `text`, empty hours as 2 px stubs, a dashed mean line) and clock labels under every fourth hour with `now`
/// under the last bar. `indexing…` before the first pass, `no transcripts` when there is nothing to index, `~stale`
/// when the charted pass is older than five minutes.
struct BurnChartView: View {
    @Environment(\.palette) private var palette
    let burn: BurnSummary?
    let chart: BurnChart?
    let stale: Bool

    private let gutter: CGFloat = 64
    private let axisHeight: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tokens burned per hour · 24 h").sectionLabel(palette).lineLimit(1)
                Spacer()
                Text(headline).font(PanelType.mono(17)).foregroundStyle(palette.muted)
            }
            if let chart = readyChart {
                let yLabels = BurnAxis.yLabels(peak: chart.peak)
                let xLabels = BurnAxis.xLabels(bars: chart.bars)
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .trailing, spacing: 0) {
                        axisText(yLabels[0])
                        Spacer(minLength: 0)
                        axisText(yLabels[1])
                        Spacer(minLength: 0)
                        axisText(yLabels[2])
                    }
                    .frame(width: gutter - 8, alignment: .trailing)
                    .padding(.bottom, axisHeight + 4)
                    VStack(spacing: 4) {
                        Canvas { context, size in draw(chart, in: context, size: size) }
                        GeometryReader { geo in
                            let slot = geo.size.width / CGFloat(max(chart.bars.count, 1))
                            ZStack(alignment: .topLeading) {
                                ForEach(xLabels, id: \.index) { item in
                                    axisText(item.label)
                                        .frame(width: slot * 3, alignment: .center)
                                        .position(x: slot * (CGFloat(item.index) + 0.5), y: axisHeight / 2)
                                }
                            }
                        }
                        .frame(height: axisHeight)
                    }
                }
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private func axisText(_ s: String) -> some View {
        Text(s).font(PanelType.mono(17)).foregroundStyle(palette.muted).lineLimit(1)
    }

    /// A chart is only "ready" once a full pass found at least one transcript.
    private var readyChart: BurnChart? { (burn?.fileCount ?? 0) > 0 ? chart : nil }

    private var headline: String {
        if readyChart != nil { return stale ? "~stale" : "" }
        if let burn, burn.complete, burn.fileCount == 0 { return "no transcripts" }
        return "indexing…"
    }

    private func draw(_ chart: BurnChart, in context: GraphicsContext, size: CGSize) {
        let n = chart.bars.count
        guard n > 0 else { return }
        let gap: CGFloat = 4
        let barWidth = (size.width - gap * CGFloat(n - 1)) / CGFloat(n)
        let peak = CGFloat(max(chart.peak, 1))
        for (i, bar) in chart.bars.enumerated() {
            let x = CGFloat(i) * (barWidth + gap)
            let height = bar.isEmpty ? 2 : max(2, size.height * CGFloat(bar.burn) / peak)
            let rect = CGRect(x: x, y: size.height - height, width: barWidth, height: height)
            let color: Color = bar.isEmpty ? palette.line : (i == n - 1 ? palette.text : palette.accent)
            context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
        }
        if chart.mean > 0 {
            let y = size.height - size.height * CGFloat(chart.mean) / peak
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(line, with: .color(palette.muted), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        }
    }
}
