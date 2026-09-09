import Foundation

public enum XeneonEdgeDevice {
    public static let vendorID = 0x27C0
    public static let productID = 0x0859
    public static let touchReportID = 7
    public static let touchReportLength = 7
    public static let rawXMax = 16383
    public static let rawYMax = 9599
}

public struct TouchEvent: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case down, move, up }
    public let kind: Kind
    public let rawX: Int
    public let rawY: Int
    public let time: TimeInterval
    public init(kind: Kind, rawX: Int, rawY: Int, time: TimeInterval) {
        self.kind = kind; self.rawX = rawX; self.rawY = rawY; self.time = time
    }
}
