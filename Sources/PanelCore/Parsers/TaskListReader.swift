import Foundation

public enum TaskListReader {
    public static func parse(files: [(name: String, data: Data)]) -> [TaskItem] {
        files.compactMap { file -> TaskItem? in
            guard file.name.hasSuffix(".json"),
                  let o = (try? JSONSerialization.jsonObject(with: file.data)) as? [String: Any] else { return nil }
            let idString = (o["id"] as? String) ?? String(file.name.dropLast(5))
            guard let id = Int(idString) else { return nil }
            let subject = (o["subject"] as? String) ?? (o["activeForm"] as? String) ?? "Task \(id)"
            return TaskItem(id: id, subject: subject, status: TaskStatus(claudeString: o["status"] as? String))
        }
        .sorted { $0.id < $1.id }
    }

    public static func read(directory: URL) -> [TaskItem] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        let files = names.compactMap { name -> (name: String, data: Data)? in
            guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
            return (name, data)
        }
        return parse(files: files)
    }
}
