import Foundation

public enum AgentsListParser {
    public struct ParseError: Error, Equatable {
        public let message: String
    }

    public static func parse(_ data: Data) throws -> [Session] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ParseError(message: "invalid JSON: \(error)")
        }
        guard let array = object as? [[String: Any]] else {
            throw ParseError(message: "top level is not an array of objects")
        }
        return array.compactMap(parseEntry)
    }

    static func parseEntry(_ o: [String: Any]) -> Session? {
        guard let sessionId = o["sessionId"] as? String, !sessionId.isEmpty else { return nil }
        let cwd = (o["cwd"] as? String) ?? ""
        let kind = SessionKind(rawValue: (o["kind"] as? String) ?? "") ?? .interactive
        let statusRaw = (o["status"] as? String) ?? (o["state"] as? String)
        let name = (o["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? (o["id"] as? String)
            ?? String(sessionId.prefix(8))
        let startedMs = (o["startedAt"] as? Double) ?? 0
        return Session(
            sessionId: sessionId,
            name: name,
            cwd: cwd,
            pid: o["pid"] as? Int,
            kind: kind,
            status: SessionStatus(claudeString: statusRaw),
            startedAt: Date(timeIntervalSince1970: startedMs / 1000),
            jobId: o["id"] as? String
        )
    }
}
