import Foundation

/// Handoff indicator §A: the step a running handoff is waiting on, as the card and the sheet show it. The runner
/// publishes one per pid from the tap until the paste lands or the sequence fails.
public enum HandoffStage: Equatable, Sendable {
    /// `/handoff` is being typed.
    case requesting
    /// Review 2026-09-10: `/handoff` typed into a busy session sits in Claude Code's queue until the turn ends.
    case queued
    /// `/handoff` landed; waiting for the skill's reply in the transcript.
    case awaitingReply
    /// `/clear` typed; waiting for the session file to carry a new session id.
    case clearing
    /// The block is being pasted into the cleared session.
    case pasting

    /// The suffix after `HANDOFF` in the card's status row.
    public var label: String {
        switch self {
        case .requesting, .awaitingReply: "· reply"
        case .queued: "· queued"
        case .clearing: "· clear"
        case .pasting: "· paste"
        }
    }
}
