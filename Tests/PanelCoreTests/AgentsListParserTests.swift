import Foundation
import Testing
@testable import PanelCore

@Suite struct AgentsListParserTests {
    // Captured from `claude agents --json` on 2026-09-06 (Claude Code 2.1.261).
    static let fixture = """
    [
     {"id":"1a2b3c4d","cwd":"/Users/dev/Desktop/demo-app","kind":"background","startedAt":1783862085237,
      "sessionId":"1a2b3c4d-0000-4000-8000-000000000001","name":"fanout-worker","state":"blocked"},
     {"pid":13268,"cwd":"/Users/dev/Desktop/demo-app","kind":"interactive","startedAt":1788486022382,
      "sessionId":"4d5e6f70-0000-4000-8000-000000000004","name":"demo-app-b8","status":"idle"},
     {"pid":10631,"cwd":"/Users/dev/Desktop/demo-app","kind":"interactive","startedAt":1788624691266,
      "sessionId":"2b3c4d5e-0000-4000-8000-000000000002","name":"demo-app-43","status":"busy"},
     {"pid":18901,"cwd":"/Users/dev/Desktop/demo-app","kind":"interactive","startedAt":1788631007258,
      "sessionId":"3c4d5e6f-0000-4000-8000-000000000003","name":"demo-app-f0","status":"waiting"}
    ]
    """.data(using: .utf8)!

    @Test func parsesInteractiveAndBackground() throws {
        let sessions = try AgentsListParser.parse(Self.fixture)
        #expect(sessions.count == 4)

        let bg = try #require(sessions.first { $0.sessionId == "1a2b3c4d-0000-4000-8000-000000000001" })
        #expect(bg.kind == .background)
        #expect(bg.pid == nil)
        #expect(bg.status == .blocked)
        #expect(bg.name == "fanout-worker")
        #expect(bg.startedAt == Date(timeIntervalSince1970: 1_783_862_085.237))

        let waiting = try #require(sessions.first { $0.name == "demo-app-f0" })
        #expect(waiting.kind == .interactive)
        #expect(waiting.pid == 18901)
        #expect(waiting.status == .waiting)
        #expect(waiting.cwd == "/Users/dev/Desktop/demo-app")
    }

    @Test func backgroundEntriesKeepTheirJobId() throws {
        let sessions = try AgentsListParser.parse(Self.fixture)
        let bg = try #require(sessions.first { $0.sessionId == "1a2b3c4d-0000-4000-8000-000000000001" })
        #expect(bg.jobId == "1a2b3c4d")
        let interactive = try #require(sessions.first { $0.name == "demo-app-b8" })
        #expect(interactive.jobId == nil)
    }

    @Test func unknownStatusBecomesUnknown() throws {
        let data = #"[{"pid":1,"cwd":"/x","kind":"interactive","startedAt":0,"sessionId":"s1","name":"n","status":"teleporting"}]"#.data(using: .utf8)!
        let sessions = try AgentsListParser.parse(data)
        #expect(sessions.first?.status == .unknown)
    }

    @Test func entriesWithoutSessionIdAreSkipped() throws {
        let data = #"[{"pid":1,"cwd":"/x","kind":"interactive","startedAt":0,"name":"n","status":"busy"}]"#.data(using: .utf8)!
        #expect(try AgentsListParser.parse(data).isEmpty)
    }

    @Test func missingNameFallsBackToShortId() throws {
        let data = #"[{"cwd":"/x","kind":"background","startedAt":0,"sessionId":"abcdef12-3456","state":"blocked"}]"#.data(using: .utf8)!
        #expect(try AgentsListParser.parse(data).first?.name == "abcdef12")
    }

    @Test func emptyArrayIsFine() throws {
        #expect(try AgentsListParser.parse("[]".data(using: .utf8)!).isEmpty)
    }

    @Test func nonArrayThrows() {
        #expect(throws: AgentsListParser.ParseError.self) {
            try AgentsListParser.parse("{}".data(using: .utf8)!)
        }
    }
}
