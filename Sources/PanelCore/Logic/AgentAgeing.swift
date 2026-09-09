import Foundation

public enum AgentAgeing {
    /// Spec 2026-09-07 §3.1: a background agent whose age (now − job `updatedAt`, else now − `startedAt`)
    /// exceeds `maxAgeHours` is dropped before sorting. `0` disables ageing. Interactive sessions are never
    /// aged — their liveness is the pid check.
    public static func filter(_ sessions: [Session], jobs: [String: JobInfo], maxAgeHours: Int, now: Date) -> [Session] {
        guard maxAgeHours > 0 else { return sessions }
        let limit = TimeInterval(maxAgeHours) * 3600
        return sessions.filter { session in
            guard session.kind == .background else { return true }
            let reference = jobs[session.sessionId]?.updatedAt ?? session.startedAt
            return now.timeIntervalSince(reference) <= limit
        }
    }
}
