import Foundation
import Testing
@testable import PanelCore

@Suite struct MascotLoaderTests {
    static let tiny = """
    {"id":"tiny","displayName":"Tiny","cols":4,"rows":2,"palette":["#FF0000","#00FF00"],"charMap":{"R":0,"G":1},
     "tiers":{"sleep":[["RR.G","...."]],"bored":[["R.RG","GGGG"],["....","...."]],"cruise":[["RRRR","...."]],"fast":[["RRRR","...."]],"top":[["RRRR","G..G"]]}}
    """.data(using: .utf8)!

    @Test func convertsRowsToRuns() throws {
        let m = try MascotLoader.load(Self.tiny)
        #expect(m.id == "tiny")
        #expect(m.cols == 4 && m.rows == 2)
        #expect(m.palette == [RGB(hex: "#FF0000")!, RGB(hex: "#00FF00")!])
        let sleep = try #require(m.frames[.sleep]?.first)
        #expect(sleep.runs[0] == [PixelRun(x: 0, length: 2, colorIndex: 0), PixelRun(x: 3, length: 1, colorIndex: 1)])
        #expect(sleep.runs[1].isEmpty)
        #expect(m.frames[.bored]?.count == 2)
    }

    @Test func framesForPoseFallsBackToCruise() throws {
        var json = String(data: Self.tiny, encoding: .utf8)!
        json = json.replacingOccurrences(of: #""fast":[["RRRR","...."]],"#, with: "")
        let m = try MascotLoader.load(json.data(using: .utf8)!)
        #expect(m.frames(for: .fast) == m.frames(for: .cruise))
    }

    @Test func rejectsRaggedFrames() {
        let bad = ##"{"id":"b","displayName":"B","cols":2,"rows":1,"palette":["#000000"],"charMap":{"O":0},"tiers":{"cruise":[["OOO"]]}}"##.data(using: .utf8)!
        #expect(throws: MascotLoader.LoadError.self) { try MascotLoader.load(bad) }
    }

    @Test func rejectsUnknownCharacters() {
        let bad = ##"{"id":"b","displayName":"B","cols":2,"rows":1,"palette":["#000000"],"charMap":{"O":0},"tiers":{"cruise":[["OX"]]}}"##.data(using: .utf8)!
        #expect(throws: MascotLoader.LoadError.self) { try MascotLoader.load(bad) }
    }

    @Test func rgbParsesHex() throws {
        let c = try #require(RGB(hex: "#B3A6EA"))
        #expect(abs(c.r - 179.0 / 255.0) < 0.001 && abs(c.g - 166.0 / 255.0) < 0.001 && abs(c.b - 234.0 / 255.0) < 0.001)
        #expect(RGB(hex: "B3A6EA") != nil)
        #expect(RGB(hex: "#GGGGGG") == nil)
        #expect(RGB(hex: "#123") == nil)
    }

    @Test func shippedMascotsAllLoad() throws {
        let all = try MascotLibrary.loadAll()
        #expect(Set(all.map(\.id)) == ["mage", "ruby", "miko", "ivory", "aria", "lilac", "iris", "stella", "rosalie"])
        // Roster spec §6: one hair-wave loop (cruise) and the "needs you" alert (top); the other poses fall back to cruise.
        let expected: [MascotPose: Int] = [.cruise: 8, .top: 8]
        for m in all {
            #expect(m.cols == 68 && m.rows == 67, "\(m.id) is not 68x67")
            #expect(m.palette.count <= 16, "\(m.id) has \(m.palette.count) colours")
            for (pose, count) in expected {
                #expect(m.frames[pose]?.count == count, "\(m.id)/\(pose) has \(m.frames[pose]?.count ?? 0) frames, expected \(count)")
            }
            #expect(Set(m.frames.keys) == [.cruise, .top], "\(m.id) ships tiers \(m.frames.keys)")
            #expect(m.frames(for: .sleep) == m.frames(for: .cruise), "\(m.id)/sleep does not fall back to cruise")
        }
    }
}
