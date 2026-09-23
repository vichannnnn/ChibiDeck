import Foundation

/// Spec 2026-09-23 §4.3: a file's size and modification date, the cheap "did it change" test (APFS dates carry
/// nanoseconds, so a same-size rewrite still moves the stamp).
public struct FileStamp: Sendable, Equatable {
    public let size: Int
    public let modified: Date

    public init(size: Int, modified: Date) {
        self.size = size
        self.modified = modified
    }
}

/// Spec 2026-09-23 §4.3: the stamp each path was last parsed at. Read a file again when its path is new, its stamp
/// cannot be taken, or its stamp moved; `retain` drops paths that left the live set (Plan 3 §9.2: nothing keyed by a
/// session outlives the listing).
public struct ChangeGate: Sendable {
    private var stamps: [String: FileStamp] = [:]

    public init() {}

    public func shouldRead(_ path: String, stamp: FileStamp?) -> Bool {
        guard let stamp else { return true }
        return stamps[path] != stamp
    }

    public mutating func markRead(_ path: String, stamp: FileStamp?) {
        stamps[path] = stamp
    }

    public mutating func retain(_ paths: Set<String>) {
        stamps = stamps.filter { paths.contains($0.key) }
    }

    public var count: Int { stamps.count }
}
