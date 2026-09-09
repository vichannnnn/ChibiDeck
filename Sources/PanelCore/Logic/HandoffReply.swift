import Foundation

/// Handoff §4: what gets pasted into the cleared session. The handoff skill replies with one fenced block; the
/// block's content is the deliverable, so the fences (and a language tag) go. A reply without a complete fence
/// is no reply at all (nil): an API-error sentence or a stray remark must never be pasted into a cleared session.
public enum HandoffReply {
    public static func block(in text: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        guard let open = lines.firstIndex(where: { fenceLength($0) > 0 }) else { return nil }
        let ticks = fenceLength(lines[open])
        guard let close = lines[(open + 1)...].firstIndex(where: { fenceLength($0) >= ticks && isBareFence($0) }) else { return nil }
        let content = lines[(open + 1)..<close].joined(separator: "\n").trimmingCharacters(in: .newlines)
        return content.isEmpty ? nil : content
    }

    /// Number of leading backticks after optional indentation; 0 when the line does not open or close a fence.
    static func fenceLength(_ line: String) -> Int {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let count = trimmed.prefix { $0 == "`" }.count
        return count >= 3 ? count : 0
    }

    /// A closing fence is backticks and nothing else; an opening fence may carry a language tag.
    static func isBareFence(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "`" }
    }
}
