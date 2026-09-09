import Foundation

/// What one panel action (Focus tab, Continue) came to. `unavailable` is a permanent "not for this session";
/// `failed` carries the text the panel shows as a toast.
public enum ActionResult: Equatable, Sendable {
    case done
    case unavailable(String)
    case failed(String)
}
