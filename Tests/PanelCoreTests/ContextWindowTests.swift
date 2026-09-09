import Foundation
import Testing
@testable import PanelCore

@Suite struct ContextWindowTests {
    @Test func tableFromSpec() {
        #expect(ContextWindow.defaultSize(modelId: "claude-opus-5", displayName: nil) == 200_000)
        #expect(ContextWindow.defaultSize(modelId: "claude-sonnet-5[1m]", displayName: nil) == 1_000_000)
        #expect(ContextWindow.defaultSize(modelId: nil, displayName: "Sonnet 5 1M") == 1_000_000)
        #expect(ContextWindow.defaultSize(modelId: "claude-fable-5-1", displayName: nil) == 1_000_000)
        #expect(ContextWindow.defaultSize(modelId: nil, displayName: "Fable 5.1") == 1_000_000)
        #expect(ContextWindow.defaultSize(modelId: nil, displayName: nil) == 200_000)
    }

    @Test func reconcileBumpsOnlyWhenObservedExceedsSize() {
        #expect(ContextWindow.reconcile(size: 200_000, observedTokens: 150_000) == 200_000)
        #expect(ContextWindow.reconcile(size: 200_000, observedTokens: 200_000) == 200_000)
        #expect(ContextWindow.reconcile(size: 200_000, observedTokens: 527_137) == 1_000_000)
        #expect(ContextWindow.reconcile(size: 1_000_000, observedTokens: 1_200_000) == 1_000_000)
    }
}
