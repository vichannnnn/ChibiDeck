import Foundation

public struct RGB: Sendable, Equatable, Hashable {
    public let r: Double
    public let g: Double
    public let b: Double

    public init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    /// Accepts `#RRGGBB` or `RRGGBB`.
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(r: Double((v >> 16) & 0xFF) / 255, g: Double((v >> 8) & 0xFF) / 255, b: Double(v & 0xFF) / 255)
    }
}

public enum MascotPose: String, Sendable, CaseIterable, Equatable {
    case sleep, bored, cruise, fast, top
}

public struct PixelRun: Sendable, Equatable {
    public let x: Int
    public let length: Int
    public let colorIndex: Int
    public init(x: Int, length: Int, colorIndex: Int) { self.x = x; self.length = length; self.colorIndex = colorIndex }
}

public struct MascotFrame: Sendable, Equatable {
    /// One array of runs per row, top to bottom.
    public let runs: [[PixelRun]]
    public init(runs: [[PixelRun]]) { self.runs = runs }
}

public struct Mascot: Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let cols: Int
    public let rows: Int
    public let palette: [RGB]
    public let frames: [MascotPose: [MascotFrame]]

    public init(id: String, displayName: String, cols: Int, rows: Int, palette: [RGB], frames: [MascotPose: [MascotFrame]]) {
        self.id = id; self.displayName = displayName; self.cols = cols; self.rows = rows; self.palette = palette; self.frames = frames
    }

    /// Frames for a pose, falling back to `cruise`, then to any pose, so a sprite missing a tier still draws.
    /// The shipped sprites carry only `cruise` (the hair-wave loop) and `top` (the "needs you" alert), roster spec §6.
    public func frames(for pose: MascotPose) -> [MascotFrame] {
        if let f = frames[pose], !f.isEmpty { return f }
        if let f = frames[.cruise], !f.isEmpty { return f }
        return frames.values.first { !$0.isEmpty } ?? []
    }
}
