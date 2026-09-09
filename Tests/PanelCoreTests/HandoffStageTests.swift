import Foundation
import Testing
@testable import PanelCore

@Suite struct HandoffStageTests {
    @Test func labelsNameTheStepTheCardIsWaitingOn() {
        #expect(HandoffStage.requesting.label == "· reply")
        #expect(HandoffStage.awaitingReply.label == "· reply")
        #expect(HandoffStage.clearing.label == "· clear")
        #expect(HandoffStage.pasting.label == "· paste")
    }

    @Test func onlyTheLivePhasesMapToAStage() {
        #expect(HandoffStage(phase: .requested) == .awaitingReply)
        #expect(HandoffStage(phase: .clearing) == .clearing)
        #expect(HandoffStage(phase: .done) == nil)
        #expect(HandoffStage(phase: .failed("x")) == nil)
    }
}
