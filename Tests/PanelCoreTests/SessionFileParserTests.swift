import Foundation
import Testing
@testable import PanelCore

@Suite struct SessionFileParserTests {
    // Captured from ~/.claude/sessions/18901.json on 2026-09-06 while the session waited for input.
    static let waiting = """
    {"pid":18901,"sessionId":"3c4d5e6f-0000-4000-8000-000000000003","cwd":"/Users/dev/Desktop/demo-app",
     "startedAt":1788631007258,"procStart":"Sat Sep  5 17:56:45 2026","version":"2.1.261","peerProtocol":1,
     "peerFeatures":["notify_idle","reply_across_default_dirs","artifact_yield"],"kind":"interactive","entrypoint":"cli",
     "pidDomain":"darwin","messagingSocketPath":"/tmp/cc-socks/18901.sock","name":"demo-app-f0","nameSource":"derived",
     "nameSince":1788631007258,"status":"waiting","updatedAt":1788653677538,"statusUpdatedAt":1788653677538,
     "bridgeSessionId":null,"waitingFor":"input needed"}
    """.data(using: .utf8)!

    @Test func parsesWaitingSession() throws {
        let r = try #require(SessionFileParser.parse(Self.waiting))
        #expect(r.pid == 18901)
        #expect(r.sessionId == "3c4d5e6f-0000-4000-8000-000000000003")
        #expect(r.name == "demo-app-f0")
        #expect(r.cwd == "/Users/dev/Desktop/demo-app")
        #expect(r.status == .waiting)
        #expect(r.waitingFor == "input needed")
        #expect(r.statusUpdatedAt == Date(timeIntervalSince1970: 1_788_653_677.538))
        #expect(r.startedAt == Date(timeIntervalSince1970: 1_788_631_007.258))
    }

    @Test func idleSessionHasNoWaitingFor() throws {
        let data = #"{"pid":5,"sessionId":"s","status":"idle","updatedAt":1000,"statusUpdatedAt":1000}"#.data(using: .utf8)!
        let r = try #require(SessionFileParser.parse(data))
        #expect(r.status == .idle)
        #expect(r.waitingFor == nil)
        #expect(r.name == nil)
    }

    @Test func missingPidOrSessionIdReturnsNil() {
        #expect(SessionFileParser.parse(#"{"sessionId":"s","status":"idle"}"#.data(using: .utf8)!) == nil)
        #expect(SessionFileParser.parse(#"{"pid":5,"status":"idle"}"#.data(using: .utf8)!) == nil)
    }

    @Test func malformedJSONReturnsNil() {
        #expect(SessionFileParser.parse("{not json".data(using: .utf8)!) == nil)
    }
}
