import Foundation
import Testing
@testable import PanelCore

@Suite struct MascotRasterTests {
    static let palette = [RGB(hex: "#FF0000")!, RGB(hex: "#00FF80")!]
    static let frame = MascotFrame(runs: [[PixelRun(x: 1, length: 2, colorIndex: 0)], [], [PixelRun(x: 0, length: 1, colorIndex: 1)]])

    static func px(_ bytes: [UInt8], _ x: Int, _ y: Int, cols: Int) -> [UInt8] {
        let i = (y * cols + x) * 4
        return Array(bytes[i..<(i + 4)])
    }

    @Test func bytesCoverEveryPixel() {
        #expect(MascotRaster.rgba(Self.frame, palette: Self.palette, cols: 4, rows: 3).count == 4 * 3 * 4)
        #expect(MascotRaster.rgba(MascotFrame(runs: []), palette: [], cols: 68, rows: 67).count == 68 * 67 * 4)
    }

    @Test func runsCarryTheirPaletteColourAndTheRestIsTransparent() {
        let b = MascotRaster.rgba(Self.frame, palette: Self.palette, cols: 4, rows: 3)
        #expect(Self.px(b, 0, 0, cols: 4) == [0, 0, 0, 0])
        #expect(Self.px(b, 1, 0, cols: 4) == [255, 0, 0, 255] && Self.px(b, 2, 0, cols: 4) == [255, 0, 0, 255])
        #expect(Self.px(b, 3, 0, cols: 4) == [0, 0, 0, 0])
        #expect(Self.px(b, 1, 1, cols: 4) == [0, 0, 0, 0])
        #expect(Self.px(b, 0, 2, cols: 4) == [0, 255, 128, 255])
    }

    @Test func runsPastTheEdgeAreCutAndBadIndicesSkipped() {
        let wide = MascotFrame(runs: [[PixelRun(x: 3, length: 5, colorIndex: 0), PixelRun(x: 9, length: 2, colorIndex: 0), PixelRun(x: 0, length: 1, colorIndex: 7)]])
        let b = MascotRaster.rgba(wide, palette: Self.palette, cols: 4, rows: 1)
        #expect(b.count == 16)
        #expect(Self.px(b, 3, 0, cols: 4) == [255, 0, 0, 255])
        #expect(Self.px(b, 0, 0, cols: 4) == [0, 0, 0, 0])
    }

    @Test func shippedMascotsRasterise() throws {
        for m in try MascotLibrary.loadAll() {
            let frame = try #require(m.frames(for: .cruise).first)
            let bytes = MascotRaster.rgba(frame, palette: m.palette, cols: m.cols, rows: m.rows)
            #expect(bytes.count == m.cols * m.rows * 4)
            #expect(stride(from: 3, to: bytes.count, by: 4).contains { bytes[$0] == 255 }, "\(m.id) drew nothing")
        }
    }
}
