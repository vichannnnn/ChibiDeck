import Foundation

/// Character select §5: one row of tiles across the 2560×720 canvas, the sprite at the largest integer scale that
/// fits the roster. Pure, so the numbers are tested and the view only draws.
public struct CharacterSelectLayout: Sendable {      // no Equatable: CGRect’s conformance lives in CoreGraphics, which PanelCore does not import (see TouchRegion)
    public static let canvas = CGSize(width: 2560, height: 720)
    public static let spriteCols = 68
    public static let spriteRows = 67
    /// Around the sprite: left, right and top of the tile.
    public static let tilePadding: CGFloat = 12
    /// Between tiles.
    public static let gap: CGFloat = 16
    /// Least space left of the first tile and right of the last.
    public static let margin: CGFloat = 32
    /// 8 between the sprite and the name, a 30 pt name line, a 22 pt theme line.
    public static let captionHeight: CGFloat = 60

    public let scale: Int
    public let tileSize: CGSize
    public let frames: [CGRect]

    public init(count: Int) {
        let s = Self.scale(for: count)
        let size = Self.tileSize(scale: s)
        scale = s
        tileSize = size
        guard count > 0 else { frames = []; return }
        let rowWidth = CGFloat(count) * size.width + CGFloat(count - 1) * Self.gap
        let x0 = ((Self.canvas.width - rowWidth) / 2).rounded(.down)
        let y0 = ((Self.canvas.height - size.height) / 2).rounded(.down)
        frames = (0..<count).map { i in
            CGRect(origin: CGPoint(x: x0 + CGFloat(i) * (size.width + Self.gap), y: y0), size: size)
        }
    }

    /// The largest scale in 3…1 whose row of `count` tiles fits between the margins; 1 when nothing fits.
    public static func scale(for count: Int) -> Int {
        let available = canvas.width - 2 * margin
        for s in stride(from: 3, through: 1, by: -1) {
            let row = CGFloat(count) * tileSize(scale: s).width + CGFloat(max(count - 1, 0)) * gap
            if row <= available { return s }
        }
        return 1
    }

    static func tileSize(scale s: Int) -> CGSize {
        CGSize(width: CGFloat(spriteCols * s) + 2 * tilePadding,
               height: CGFloat(spriteRows * s) + tilePadding + captionHeight + tilePadding)
    }
}
