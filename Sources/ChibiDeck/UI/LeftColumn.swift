import SwiftUI
import PanelCore

/// Spec 2026-09-07 §2.2 as amended by spec 2026-09-23 §5: character at 5× (tap = next theme; Character select §3: hold = the character select), clock, date.
/// Plan 3 §7: up to two permission lines in blocked red under the `stale` slot (y 415 and 439 since spec 2026-09-23 §5), only while something is denied.
struct LeftColumn: View, Equatable {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    /// Spec 2026-09-23 §4.2: the column's own inputs; the mascot, permissions and dimming are observed from the model.
    let now: Date
    let isStale: Bool
    let pose: MascotPose

    static func == (a: LeftColumn, b: LeftColumn) -> Bool { a.now == b.now && a.isStale == b.isStale && a.pose == b.pose }

    var body: some View {
        VStack(spacing: 0) {
            MascotView(mascot: model.currentMascot, pose: pose, scale: 5, desaturated: isStale)   // spec 2026-09-23 §5: 340×335 at x 30, y 40
                .contentShape(Rectangle())
                .onTapGesture { model.perform(.mascot) }
                .simultaneousGesture(LongPressGesture(minimumDuration: LongPressRecognizer.minimumDuration)
                    .onEnded { _ in model.perform(.characterSelect) })       // Character select §3: the mouse path; the release click is ignored while the screen is open
                .touchTarget(.mascot)
                .padding(.top, 40)
            Text(isStale ? "stale" : " ")
                .font(PanelType.mono(17)).foregroundStyle(palette.muted).frame(height: 24).padding(.top, 8)
            VStack(spacing: 0) {
                ForEach(model.permissions.lines, id: \.self) { line in
                    Text(line).font(PanelType.mono(17)).foregroundStyle(ThemePalette.blocked).lineLimit(1).frame(height: 24)
                }
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
            Text(PanelFormat.hhmm(now))
                .font(PanelType.mono(model.ui.isDimmed ? 120 : 110, .heavy)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(dateLine).font(PanelType.mono(24, .bold)).foregroundStyle(palette.muted).textCase(.uppercase).padding(.top, 12)
            Spacer().frame(height: 60)
        }
        .frame(width: 400, height: 720)
        .overlay(alignment: .trailing) { Rectangle().fill(palette.line).frame(width: 1) }
    }

    /// `Mon 7 Sep`, uppercased by the view; pinned to English like `PanelFormat.reset`.
    private var dateLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE d MMM"
        return f.string(from: now)
    }
}
