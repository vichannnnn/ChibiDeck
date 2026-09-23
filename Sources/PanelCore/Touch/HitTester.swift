import Foundation

/// Plan 3 §5.2: the region containing the point with the highest `z`; among equal `z`, the last registered.
/// Empty frames never hit. The min edge is inside and the max edge is outside.
public enum HitTester {
    public static func hit(x: Double, y: Double, regions: [TouchRegion]) -> TouchTarget? {
        var best: TouchRegion?
        for region in regions where contains(region, x: x, y: y) {
            if let current = best, region.z < current.z { continue }
            best = region
        }
        return best?.target
    }

    /// Spec 2026-09-23 §8.7: inside the frame and, when the region has one, inside its clip.
    private static func contains(_ region: TouchRegion, x: Double, y: Double) -> Bool {
        guard pointInRect(x: x, y: y, rect: region.frame) else { return false }
        guard let clip = region.clip else { return true }
        return pointInRect(x: x, y: y, rect: clip)
    }

    private static func pointInRect(x: Double, y: Double, rect: CGRect) -> Bool {
        guard rect.size.width > 0 && rect.size.height > 0 else { return false }
        let maxX = rect.origin.x + rect.size.width
        let maxY = rect.origin.y + rect.size.height
        return x >= rect.origin.x && x < maxX && y >= rect.origin.y && y < maxY
    }
}
