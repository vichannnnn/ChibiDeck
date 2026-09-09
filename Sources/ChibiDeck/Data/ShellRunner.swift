import Foundation
import os

enum ShellError: Error, Equatable {
    case exit(Int32)
    case timeout
    case launch(String)
}

enum ShellRunner {
    /// Grace period after SIGTERM before we escalate to SIGKILL.
    private static let forceKillGrace: TimeInterval = 2

    /// Runs a process off the main thread with a hard timeout; returns stdout on exit 0.
    /// If the child ignores SIGTERM, escalates to SIGKILL after `forceKillGrace` so a
    /// trapping/hung process can never block this call (and its caller's in-flight guard) forever.
    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 10, cwd: String? = nil) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: executable)
                p.arguments = arguments
                if let cwd { p.currentDirectoryURL = URL(fileURLWithPath: cwd) }
                var env = ProcessInfo.processInfo.environment
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                env["PATH"] = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
                p.environment = env
                let out = Pipe()
                p.standardOutput = out
                p.standardError = FileHandle.nullDevice
                do { try p.run() } catch { cont.resume(throwing: ShellError.launch("\(error)")); return }
                let timedOut = OSAllocatedUnfairLock(initialState: false)
                let forceKill = DispatchWorkItem { if p.isRunning { kill(p.processIdentifier, SIGKILL) } }
                let killer = DispatchWorkItem {
                    guard p.isRunning else { return }
                    timedOut.withLock { $0 = true }
                    p.terminate()
                    DispatchQueue.global().asyncAfter(deadline: .now() + forceKillGrace, execute: forceKill)
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
                let data = out.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                killer.cancel()
                forceKill.cancel()
                if timedOut.withLock({ $0 }) { cont.resume(throwing: ShellError.timeout) }
                else if p.terminationStatus == 0 { cont.resume(returning: data) }
                else { cont.resume(throwing: ShellError.exit(p.terminationStatus)) }
            }
        }
    }
}
