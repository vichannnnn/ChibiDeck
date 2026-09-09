import Foundation
import Testing
@testable import PanelCore

@Suite struct HandoffReplyTests {
    @Test func fencedBlockIsReturnedWithoutTheFences() {
        let reply = "Handoff below. Paste it as the first message.\n\n```\nYou are continuing work.\nBranch: main.\n\nGOAL\nship it\n```\nAlso saved to HANDOFF.md."
        #expect(HandoffReply.block(in: reply) == "You are continuing work.\nBranch: main.\n\nGOAL\nship it")
    }

    @Test func languageTagAndIndentedFencesAreStripped() {
        #expect(HandoffReply.block(in: "```text\nline\n```") == "line")
        #expect(HandoffReply.block(in: "  ```markdown\nline one\nline two\n  ```  ") == "line one\nline two")
    }

    @Test func fourBacktickFenceKeepsInnerThreeBacktickFences() {
        let reply = "````\nFIRST ACTION\n```bash\nswift test\n```\n````"
        #expect(HandoffReply.block(in: reply) == "FIRST ACTION\n```bash\nswift test\n```")
    }

    @Test func noCompleteFenceIsNoReply() {                                  // review 2026-09-08: an API-error sentence must not be pasted
        #expect(HandoffReply.block(in: "You've reached your limit. Run /usage-credits to continue.") == nil)
        #expect(HandoffReply.block(in: "```\nopened but never closed") == nil)
        #expect(HandoffReply.block(in: "```\n\n```") == nil)
    }

    @Test func blankLinesNextToTheFencesAreTrimmed() {
        #expect(HandoffReply.block(in: "```\n\nGOAL\nship\n\n```") == "GOAL\nship")
    }
}
