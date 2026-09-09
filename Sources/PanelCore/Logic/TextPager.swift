import Foundation

/// Plan 4 §6.1: wraps text for a monospaced box whose width is known in characters, and cuts the lines into pages.
/// The sheet cannot ask SwiftUI where a `Text` broke its lines, so it breaks them itself.
public enum TextPager {
    /// Word-wrapped lines of at most `columns` characters. Explicit newlines start a new line; a word longer than a
    /// line is split at `columns`; runs of spaces collapse to one. `columns ≤ 0` returns the text as one line.
    public static func lines(_ text: String, columns: Int) -> [String] {
        guard columns > 0 else { return [text] }
        var out: [String] = []
        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = ""
            for piece in paragraph.split(separator: " ", omittingEmptySubsequences: true) {
                var word = piece
                while word.count > columns {                       // each pass leaves 1…columns characters, never none
                    if !line.isEmpty { out.append(line); line = "" }
                    out.append(String(word.prefix(columns)))
                    word = word.dropFirst(columns)
                }
                if line.isEmpty { line = String(word) }
                else if line.count + 1 + word.count <= columns { line += " " + word }
                else { out.append(line); line = String(word) }
            }
            out.append(line)                                       // non-empty after any piece; "" keeps a blank paragraph
        }
        return out
    }

    /// Pages of `rows` lines each, joined with `\n`; always at least one page. Non-positive geometry returns the whole text.
    public static func pages(_ text: String, columns: Int, rows: Int) -> [String] {
        guard columns > 0, rows > 0 else { return [text] }
        let all = lines(text, columns: columns)
        var pages: [String] = []
        var i = 0
        while i < all.count {
            pages.append(all[i..<min(i + rows, all.count)].joined(separator: "\n"))
            i += rows
        }
        return pages.isEmpty ? [""] : pages
    }
}
