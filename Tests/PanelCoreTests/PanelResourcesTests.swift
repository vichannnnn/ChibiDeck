import Foundation
import Testing
@testable import PanelCore

@Suite struct PanelResourcesTests {
    @Test func resolvesTheResourceBundle() {
        #expect(PanelResources.bundle.bundleURL.lastPathComponent == PanelResources.bundleName)
    }

    @Test func listsBothResourceFoldersSorted() {
        let mascots = PanelResources.urls(extension: "json", subdirectory: "Mascots")
        let themes = PanelResources.urls(extension: "json", subdirectory: "Themes")
        #expect(!mascots.isEmpty)
        #expect(themes.count == 9)
        #expect(themes.map(\.lastPathComponent) == themes.map(\.lastPathComponent).sorted())
        #expect(PanelResources.urls(extension: "json", subdirectory: "Nope").isEmpty)
    }
}
