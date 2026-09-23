import Foundation
import Testing
@testable import PanelCore

@Suite struct ColorDistanceTests {
    static func c(_ hex: String) -> RGB { RGB(hex: hex)! }

    @Test func blackToWhiteIsOneHundred() {
        #expect(abs(ColorDistance.deltaE76(Self.c("#000000"), Self.c("#FFFFFF")) - 100) < 0.5)
    }

    @Test func aColourToItselfIsZero() {
        #expect(ColorDistance.deltaE76(Self.c("#B3A6EA"), Self.c("#B3A6EA")) == 0)
    }

    @Test func roseFrostsOldAccentSatOnTheBlockedRed() {            // spec 2026-09-23 §2
        #expect(abs(ColorDistance.deltaE76(Self.c("#FF8A94"), Self.c(StatusColors.blocked)) - 2.7) < 0.3)
    }

    @Test func pureRedInLab() {
        let lab = ColorDistance.lab(Self.c("#FF0000"))
        #expect(abs(lab.l - 53.24) < 0.1 && abs(lab.a - 80.09) < 0.1 && abs(lab.b - 67.20) < 0.1)
    }

    @Test func contrastRatioIsTheWcagOne() {
        #expect(abs(ColorDistance.contrastRatio(Self.c("#FFFFFF"), Self.c("#000000")) - 21) < 0.01)
        #expect(ColorDistance.contrastRatio(Self.c("#777777"), Self.c("#777777")) == 1)
    }
}
