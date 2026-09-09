import Foundation
import Testing
@testable import PanelCore

@Suite struct EdgeScreenMatchTests {
    @Test func theEdgeIsAnUltraWideXeneon() {
        #expect(EdgeScreenMatch.isEdge(name: "XENEON EDGE", width: 2560, height: 720))
        #expect(EdgeScreenMatch.isEdge(name: "Xeneon Edge", width: 1280, height: 360))      // HiDPI points
        #expect(EdgeScreenMatch.isEdge(name: "XENEON EDGE", width: 1920, height: 1080) == false)   // macOS's first 16:9 mode
        #expect(EdgeScreenMatch.isEdge(name: "XENEON 27", width: 2560, height: 1440) == false)
        #expect(EdgeScreenMatch.isEdge(name: "DELL U3421", width: 2560, height: 720) == false)
        #expect(EdgeScreenMatch.isEdge(name: "XENEON EDGE", width: 2560, height: 0) == false)
    }
}
