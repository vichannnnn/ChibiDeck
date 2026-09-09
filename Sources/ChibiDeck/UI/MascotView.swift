import SwiftUI
import PanelCore

/// Draws one sprite frame per tick (4 fps, spec 2026-09-08 §3) as horizontal runs on a Canvas. Nearest-neighbour look comes from drawing rects, not images.
struct MascotView: View {
    let mascot: Mascot
    let pose: MascotPose
    var desaturated = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let frames = mascot.frames(for: pose)
            let index = frames.isEmpty ? 0 : Int(context.date.timeIntervalSinceReferenceDate * 4) % frames.count
            Canvas(rendersAsynchronously: false) { gc, size in
                guard !frames.isEmpty else { return }
                let sx = size.width / CGFloat(mascot.cols)
                let sy = size.height / CGFloat(mascot.rows)
                for (y, row) in frames[index].runs.enumerated() {
                    for run in row {
                        let rect = CGRect(x: CGFloat(run.x) * sx, y: CGFloat(y) * sy, width: CGFloat(run.length) * sx + 0.5, height: sy + 0.5)
                        gc.fill(Path(rect), with: .color(Color(rgb: mascot.palette[run.colorIndex])))
                    }
                }
            }
            .saturation(desaturated ? 0 : 1)
            .opacity(desaturated ? 0.55 : 1)
        }
        .aspectRatio(CGFloat(mascot.cols) / CGFloat(mascot.rows), contentMode: .fit)
        .accessibilityLabel("\(mascot.displayName), \(pose.rawValue)")
    }
}
