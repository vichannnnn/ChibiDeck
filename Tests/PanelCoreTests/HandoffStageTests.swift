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
}
