import SwiftUI
import PanelCore

/// Spec 2026-09-23 §5: one pre-rendered image per sprite frame, drawn unfiltered at a whole-number `scale`, so each
/// sprite pixel covers `scale × scale` device pixels (the Edge at 1×, or HiDPI and the Retina preview at 0.5 × 2).
/// 4 fps as spec 2026-09-08 §3: a task sleeps to each `MascotClock` tick and only picks the image (not a periodic
/// `TimelineView`, which at this rate redraws the whole panel every display frame; see `MascotClock`).
struct MascotView: View {
    let mascot: Mascot
    let pose: MascotPose
    let scale: Int
    var desaturated = false
    @State private var tick = MascotClock.tick(at: Date().timeIntervalSinceReferenceDate)

    var body: some View {
        let frames = MascotImages.shared.frames(for: mascot, pose: pose)
        Group {
            if frames.isEmpty {
                Color.clear
            } else {
                Image(decorative: frames[MascotClock.frame(tick: tick, count: frames.count)], scale: 1)
                    .resizable().interpolation(.none).antialiased(false)
            }
        }
        .saturation(desaturated ? 0 : 1)
        .opacity(desaturated ? 0.55 : 1)
        .frame(width: CGFloat(mascot.cols * scale), height: CGFloat(mascot.rows * scale))
        .accessibilityLabel("\(mascot.displayName), \(pose.rawValue)")
        .task {
            while !Task.isCancelled {
                let next = MascotClock.next(after: Date().timeIntervalSinceReferenceDate)
                try? await Task.sleep(for: .seconds(next.delay))
                tick = next.tick
            }
        }
    }
}

/// Spec 2026-09-23 §5: the frames as `CGImage`s, made on first use and kept (nine mascots × two tiers × eight frames of
/// 68 × 67 pixels, about 3 MB).
@MainActor
final class MascotImages {
    static let shared = MascotImages()
    private var cache: [String: [CGImage]] = [:]

    func frames(for mascot: Mascot, pose: MascotPose) -> [CGImage] {
        let key = "\(mascot.id)/\(pose.rawValue)"
        if let hit = cache[key] { return hit }
        let images = mascot.frames(for: pose).compactMap { Self.image($0, mascot: mascot) }
        cache[key] = images
        return images
    }

    private static func image(_ frame: MascotFrame, mascot: Mascot) -> CGImage? {
        let bytes = MascotRaster.rgba(frame, palette: mascot.palette, cols: mascot.cols, rows: mascot.rows)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: mascot.cols, height: mascot.rows, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: mascot.cols * 4,
                       space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
