import Foundation

public enum JobStateParser {
    /// Empty strings count as absent; unparseable dates are nil; anything but a JSON object is nil.
    public static func parse(_ data: Data) -> JobInfo? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        func text(_ key: String) -> String? {
            guard let s = o[key] as? String else { return nil }
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return JobInfo(
            state: text("state"),
            detail: text("detail"),
            needs: text("needs"),
            suggestedReply: text("suggestedReply"),
            intent: text("intent"),
            createdAt: text("createdAt").flatMap(ISO8601.parse),
            updatedAt: text("updatedAt").flatMap(ISO8601.parse)
        )
    }
}
