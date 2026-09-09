import Foundation

/// Plan 4 §8.9: the Edge is the ultra-wide screen whose name says XENEON. A Xeneon 27" is 16:9 and must not match;
/// nor must the Edge while macOS drives it at 1920×1080 (the app then falls back to the size checks and finds nothing,
/// which is right: the panel would be letterboxed).
public enum EdgeScreenMatch {
    public static func isEdge(name: String, width: Double, height: Double) -> Bool {
        guard height > 0 else { return false }
        return name.range(of: "xeneon", options: .caseInsensitive) != nil && width / height >= 3
    }
}
