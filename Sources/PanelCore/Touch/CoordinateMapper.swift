import Foundation

public struct TouchCalibration: Sendable, Equatable {
    public var offsetX: Double
    public var offsetY: Double
    public var scaleX: Double
    public var scaleY: Double
    public init(offsetX: Double, offsetY: Double, scaleX: Double, scaleY: Double) {
        self.offsetX = offsetX; self.offsetY = offsetY; self.scaleX = scaleX; self.scaleY = scaleY
    }
    public static let identity = TouchCalibration(offsetX: 0, offsetY: 0, scaleX: 1, scaleY: 1)
}

public enum CoordinateMapper {
    /// Raw digitizer units → points in a `size`-sized panel, origin top-left, clamped to the panel.
    public static func map(rawX: Int, rawY: Int, to size: (width: Double, height: Double), calibration: TouchCalibration) -> (x: Double, y: Double) {
        let nx = Double(rawX) / Double(XeneonEdgeDevice.rawXMax)
        let ny = Double(rawY) / Double(XeneonEdgeDevice.rawYMax)
        let x = nx * size.width * calibration.scaleX + calibration.offsetX
        let y = ny * size.height * calibration.scaleY + calibration.offsetY
        return (min(max(x, 0), size.width), min(max(y, 0), size.height))
    }
}
