import Foundation
import Testing
@testable import PanelCore

@Suite struct ThemeLoaderTests {
    @Test func loadsATheme() throws {
        let data = ##"{"id":"t","name":"T","mascot":"mage","order":7,"background":"#000000","card":"#111111","line":"#222222","accent":"#333333","text":"#FFFFFF","muted":"#888888"}"##.data(using: .utf8)!
        let t = try ThemeLoader.load(data)
        #expect(t.id == "t" && t.mascot == "mage" && t.accent == "#333333" && t.order == 7)
    }

    @Test func themeWithoutOrderIsRejected() {
        let data = ##"{"id":"t","name":"T","mascot":"mage","background":"#000000","card":"#111111","line":"#222222","accent":"#333333","text":"#FFFFFF","muted":"#888888"}"##.data(using: .utf8)!
        #expect(throws: (any Error).self) { try ThemeLoader.load(data) }
    }

    @Test func shippedThemesAreOrderedAndCycle() throws {
        let themes = try ThemeLibrary.loadAll()
        #expect(themes.map(\.id) == ["midnight-witch", "lantern-red", "shrine-dusk", "porcelain", "stage-noir", "wonderland", "moonlit-iris", "starfall", "rose-frost"])
        #expect(Set(themes.map(\.order)).count == themes.count)
        #expect(ThemeLibrary.next(after: "midnight-witch", in: themes)?.id == "lantern-red")
        #expect(ThemeLibrary.next(after: "porcelain", in: themes)?.id == "stage-noir")
        #expect(ThemeLibrary.next(after: "rose-frost", in: themes)?.id == "midnight-witch")
        #expect(ThemeLibrary.next(after: "not-a-theme", in: themes)?.id == "midnight-witch")
        #expect(ThemeLibrary.next(after: "porcelain", in: []) == nil)
    }

    @Test func shippedThemesReferenceShippedMascots() throws {
        let themes = try ThemeLibrary.loadAll()
        let mascots = Set(try MascotLibrary.loadAll().map(\.id))
        #expect(themes.count == 9)
        #expect(themes.contains { $0.id == ThemeLibrary.defaultThemeId })
        for t in themes {
            #expect(mascots.contains(t.mascot), "theme \(t.id) references missing mascot \(t.mascot)")
            for hex in [t.background, t.card, t.line, t.accent, t.text, t.muted] {
                #expect(RGB(hex: hex) != nil, "theme \(t.id) has bad colour \(hex)")
            }
        }
    }
}
