import Foundation

public enum MascotLoader {
    public struct LoadError: Error, Equatable { public let message: String }

    public static func load(_ data: Data) throws -> Mascot {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw LoadError(message: "not a JSON object")
        }
        guard let id = o["id"] as? String, let cols = o["cols"] as? Int, let rows = o["rows"] as? Int,
              let paletteHex = o["palette"] as? [String], let charMap = o["charMap"] as? [String: Int],
              let tiers = o["tiers"] as? [String: [[String]]] else {
            throw LoadError(message: "missing id/cols/rows/palette/charMap/tiers")
        }
        let palette = try paletteHex.map { hex -> RGB in
            guard let c = RGB(hex: hex) else { throw LoadError(message: "bad colour \(hex)") }
            return c
        }
        var frames: [MascotPose: [MascotFrame]] = [:]
        for (tierName, frameList) in tiers {
            guard let pose = MascotPose(rawValue: tierName) else { continue }
            frames[pose] = try frameList.map { rowsOfChars in
                guard rowsOfChars.count == rows else { throw LoadError(message: "\(id)/\(tierName): expected \(rows) rows, got \(rowsOfChars.count)") }
                return MascotFrame(runs: try rowsOfChars.map { row in
                    try runs(forRow: row, cols: cols, charMap: charMap, paletteCount: palette.count, where: "\(id)/\(tierName)")
                })
            }
        }
        return Mascot(id: id, displayName: (o["displayName"] as? String) ?? id, cols: cols, rows: rows, palette: palette, frames: frames)
    }

    static func runs(forRow row: String, cols: Int, charMap: [String: Int], paletteCount: Int, where context: String) throws -> [PixelRun] {
        let chars = Array(row)
        guard chars.count == cols else { throw LoadError(message: "\(context): expected \(cols) columns, got \(chars.count)") }
        var result: [PixelRun] = []
        var x = 0
        while x < cols {
            let ch = chars[x]
            if ch == "." { x += 1; continue }
            guard let idx = charMap[String(ch)], idx >= 0, idx < paletteCount else {
                throw LoadError(message: "\(context): unknown character '\(ch)'")
            }
            var end = x
            while end < cols, chars[end] == ch { end += 1 }
            result.append(PixelRun(x: x, length: end - x, colorIndex: idx))
            x = end
        }
        return result
    }
}

public enum MascotLibrary {
    public static func loadAll() throws -> [Mascot] {
        try PanelResources.urls(extension: "json", subdirectory: "Mascots").map { try MascotLoader.load(try Data(contentsOf: $0)) }
    }
}
