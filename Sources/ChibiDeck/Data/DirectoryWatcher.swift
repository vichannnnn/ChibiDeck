import Foundation
import CoreServices

/// Watches directories with FSEvents (file-level events) and calls back on the main queue.
final class DirectoryWatcher {
    private var stream: FSEventStreamRef?
    private let paths: [String]
    private let latency: TimeInterval
    private let onChange: ([String]) -> Void

    init(paths: [URL], latency: TimeInterval = 0.25, onChange: @escaping ([String]) -> Void) {
        self.paths = paths.map(\.path)
        self.latency = latency
        self.onChange = onChange
    }

    func start() {
        guard stream == nil else { return }
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagUseCFTypes)
        guard let s = FSEventStreamCreate(kCFAllocatorDefault, { _, info, count, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            let changed = (unsafeBitCast(eventPaths, to: CFArray.self) as? [String]) ?? []
            DispatchQueue.main.async { watcher.onChange(changed) }
        }, &context, paths as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, flags) else { return }
        FSEventStreamSetDispatchQueue(s, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(s)
        stream = s
    }

    func stop() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }

    deinit { stop() }
}
