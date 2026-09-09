import Foundation

/// Plan 4 §4.4: the chart's axis labels. Pure; the view only places them.
public enum BurnAxis {
    /// Top, middle and bottom of the bar area: `12.1M`, `6M`, `0`. With no burn at all the middle label is blank.
    public static func yLabels(peak: Int) -> [String] {
        guard peak > 0 else { return ["0", "", "0"] }
        return [PanelFormat.compactTokens(peak), PanelFormat.compactTokens(peak / 2), "0"]
    }

    /// Under the bars: every bar whose local hour is a multiple of 4 gets its clock label, the last bar reads `now`,
    /// and the two bars before the last carry nothing (a 40 pt label on a 17 pt bar would touch `now`).
    public static func xLabels(bars: [HourBucket], calendar: Calendar = .current) -> [(index: Int, label: String)] {
        guard !bars.isEmpty else { return [] }
        let last = bars.count - 1
        var out: [(index: Int, label: String)] = []
        for (i, bar) in bars.enumerated() where i < last - 2 {
            if calendar.component(.hour, from: bar.hourStart) % 4 == 0 {
                out.append((index: i, label: PanelFormat.hourLabel(bar.hourStart, calendar: calendar)))
            }
        }
        out.append((index: last, label: "now"))
        return out
    }
}
