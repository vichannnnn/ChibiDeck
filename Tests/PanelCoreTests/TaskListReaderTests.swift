import Foundation
import Testing
@testable import PanelCore

@Suite struct TaskListReaderTests {
    static func file(_ name: String, _ json: String) -> (name: String, data: Data) { (name, json.data(using: .utf8)!) }

    @Test func parsesAndSortsByNumericId() {
        let items = TaskListReader.parse(files: [
            Self.file("10.json", #"{"id":"10","subject":"Tenth","status":"pending"}"#),
            Self.file("2.json", #"{"id":"2","subject":"Second","status":"in_progress","activeForm":"Doing second"}"#),
            Self.file("1.json", #"{"id":"1","subject":"First","status":"completed"}"#),
            Self.file("notes.txt", "ignored"),
        ])
        #expect(items.map(\.id) == [1, 2, 10])
        #expect(items[1].status == .inProgress)
        #expect(items[2].status == .pending)
        #expect(items[0].subject == "First")
    }

    @Test func readsADirectory() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tasks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try #"{"id":"1","subject":"A","status":"completed"}"#.write(to: dir.appendingPathComponent("1.json"), atomically: true, encoding: .utf8)
        try #"{"id":"2","subject":"B","status":"pending"}"#.write(to: dir.appendingPathComponent("2.json"), atomically: true, encoding: .utf8)
        #expect(TaskListReader.read(directory: dir).map(\.subject) == ["A", "B"])
    }

    @Test func missingDirectoryIsEmpty() {
        #expect(TaskListReader.read(directory: URL(fileURLWithPath: "/nonexistent/tasks")).isEmpty)
    }
}
