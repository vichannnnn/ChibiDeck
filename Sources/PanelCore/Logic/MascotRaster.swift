import Foundation

/// Spec 2026-09-23 §5: one sprite frame as RGBA bytes, row-major from the top-left, 4 bytes a pixel: the run's palette
/// colour with alpha 255 inside a run, all zero elsewhere. The app wraps the bytes in a `CGImage` once per frame and
/// draws it unfiltered at a whole-number scale. Runs past the edge are cut; a bad palette index draws nothing.
public enum MascotRaster {
    public static func rgba(_ frame: MascotFrame, palette: [RGB], cols: Int, rows: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: max(0, cols * rows * 4))
        for (y, runs) in frame.runs.prefix(rows).enumerated() {
            for run in runs where palette.indices.contains(run.colorIndex) {
                let lo = max(0, run.x), hi = min(cols, run.x + run.length)
                guard lo < hi else { continue }
                let c = palette[run.colorIndex]
                let r = UInt8((c.r * 255).rounded()), g = UInt8((c.g * 255).rounded()), b = UInt8((c.b * 255).rounded())
                for x in lo..<hi {
                    let i = (y * cols + x) * 4
                    bytes[i] = r; bytes[i + 1] = g; bytes[i + 2] = b; bytes[i + 3] = 255
                }
            }
        }
        return bytes
    }
}
