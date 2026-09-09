import Foundation
import Testing
@testable import PanelCore

@Suite struct JobStateParserTests {
    // Trimmed from ~/.claude/jobs/1a2b3c4d/state.json on 2026-09-07.
    static let fixture = """
    {"sessionId":"1a2b3c4d-0000-4000-8000-000000000001","name":"fanout-worker","state":"blocked",
     "detail":"pilot 32 questions ready; awaiting next step",
     "needs":"pick up at: (1) webapp review, (2) Fable round-trip on 5 flagged, or (3) rest of pilot docs",
     "suggestedReply":"run the fable pass on the 5 flagged questions",
     "intent":"Everything is merged into staging. So now, please look at the updated staging and see if your plan changes.",
     "createdAt":"2026-07-12T13:14:45.237Z","updatedAt":"2026-07-12T13:19:58.854Z",
     "template":"bg","backend":"daemon","inFlight":{"tasks":0,"queued":0,"kinds":[]},"output":{"result":"pilot extraction complete"}}
    """.data(using: .utf8)!

    @Test func parsesAllFields() throws {
        let j = try #require(JobStateParser.parse(Self.fixture))
        #expect(j.state == "blocked")
        #expect(j.detail == "pilot 32 questions ready; awaiting next step")
        #expect(j.needs?.hasPrefix("pick up at:") == true)
        #expect(j.suggestedReply == "run the fable pass on the 5 flagged questions")
        #expect(j.intent?.hasPrefix("Everything is merged") == true)
        #expect(j.createdAt == ISO8601.parse("2026-07-12T13:14:45.237Z"))
        #expect(j.updatedAt == ISO8601.parse("2026-07-12T13:19:58.854Z"))
    }

    @Test func missingAndEmptyFieldsAreNil() throws {
        let j = try #require(JobStateParser.parse(#"{"state":"running","needs":"","updatedAt":"not a date"}"#.data(using: .utf8)!))
        #expect(j.state == "running")
        #expect(j.needs == nil && j.detail == nil && j.suggestedReply == nil && j.intent == nil)
        #expect(j.updatedAt == nil && j.createdAt == nil)
    }

    @Test func malformedIsNil() {
        #expect(JobStateParser.parse("{".data(using: .utf8)!) == nil)
        #expect(JobStateParser.parse("[1,2]".data(using: .utf8)!) == nil)
    }
}
