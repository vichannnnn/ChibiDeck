import Foundation

/// Handoff indicator §A: the step a running handoff is waiting on, as the card and the sheet show it. The runner
/// publishes one per pid from the tap until the paste lands or the sequence fails.
public enum HandoffStage: Equatable, Sendable {
    /// `/handoff` is being typed.
    case requesting
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
        case .clearing: "· clear"
        case .pasting: "· paste"
        }
    }

    /// The sequencer's live phases; `done` and `failed` have no stage.
    public init?(phase: HandoffSequencer.Phase) {
        switch phase {
        case .requested: self = .awaitingReply
        case .clearing: self = .clearing
        case .done, .failed: return nil
        }
    }
}
