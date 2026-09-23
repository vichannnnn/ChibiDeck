import Foundation

public struct SessionFileRecord: Sendable, Equatable {
    public let pid: Int
    public let sessionId: String
    public let name: String?
    public let cwd: String?
    public let status: SessionStatus
    public let waitingFor: String?
    public let startedAt: Date?
    public let updatedAt: Date?
    public let statusUpdatedAt: Date?
    /// Spec 2026-09-23 §9.1: the Claude Code version that wrote the file, and the status string as written (a value
    /// `SessionStatus` does not know becomes `.unknown` and is reported by the format check).
    public var version: String? = nil
    public var rawStatus: String? = nil
}

public enum SessionFileParser {
    public static func parse(_ data: Data) -> SessionFileRecord? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let pid = o["pid"] as? Int,
              let sessionId = o["sessionId"] as? String else { return nil }
        return SessionFileRecord(
            pid: pid,
            sessionId: sessionId,
            name: o["name"] as? String,
            cwd: o["cwd"] as? String,
            status: SessionStatus(claudeString: o["status"] as? String),
            waitingFor: o["waitingFor"] as? String,
            startedAt: date(fromMs: o["startedAt"]),
            updatedAt: date(fromMs: o["updatedAt"]),
            statusUpdatedAt: date(fromMs: o["statusUpdatedAt"]),
            version: o["version"] as? String,
            rawStatus: o["status"] as? String
        )
    }

    static func date(fromMs value: Any?) -> Date? {
        guard let ms = value as? Double else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }
}
