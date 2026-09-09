import SwiftUI
import PanelCore

/// Spec 2026-09-07 §2.2: character (tap = next theme; Character select §3: hold = the character select), clock, date. Plan 3 §7: up to two permission lines
/// in blocked red under the `stale` slot (y 360 and 384), only while something is denied.
struct LeftColumn: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    let state: PanelState

    var body: some View {
        VStack(spacing: 0) {
            MascotView(mascot: model.currentMascot, pose: state.mascotPose, desaturated: state.isStale)
                .frame(width: 280, height: 280)
                .contentShape(Rectangle())
                .onTapGesture { model.perform(.mascot) }
                .simultaneousGesture(LongPressGesture(minimumDuration: LongPressRecognizer.minimumDuration)
                    .onEnded { _ in model.perform(.characterSelect) })       // Character select §3: the mouse path; the release click is ignored while the screen is open
                .touchTarget(.mascot)
                .padding(.top, 40)
            Text(state.isStale ? "stale" : " ")
                .font(PanelType.mono(17)).foregroundStyle(palette.muted).frame(height: 24).padding(.top, 8)
            VStack(spacing: 0) {
                ForEach(model.permissions.lines, id: \.self) { line in
                    Text(line).font(PanelType.mono(17)).foregroundStyle(ThemePalette.blocked).lineLimit(1).frame(height: 24)
                }
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
            Text(PanelFormat.hhmm(state.now))
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
        return f.string(from: state.now)
    }
}
