import SwiftUI
import PanelCore

/// Plan 3 §5.3: every tappable view publishes its frame on the 2560×720 canvas through this key; `PanelView`
/// collects the list into `AppModel.touchRegions` for the Edge's tap dispatcher.
struct TouchRegionKey: PreferenceKey {
    static var defaultValue: [TouchRegion] { [] }
    static func reduce(value: inout [TouchRegion], nextValue: () -> [TouchRegion]) {
        value.append(contentsOf: nextValue())
    }
}

/// Spec 2026-09-23 §8.7: the visible rectangle, on the canvas, that the regions registered below it are clipped to.
private struct TouchClipKey: EnvironmentKey {
    static let defaultValue: CGRect? = nil
}

extension EnvironmentValues {
    var touchClip: CGRect? {
        get { self[TouchClipKey.self] }
        set { self[TouchClipKey.self] = newValue }
    }
}

/// Registers the view's frame (in `PanelView.coordinateSpace`, i.e. canvas points) as a touch region, clipped to the
/// environment's `touchClip` when one is set.
private struct TouchTargetModifier: ViewModifier {
    @Environment(\.touchClip) private var clip
    let target: TouchTarget
    let z: Int

    func body(content: Content) -> some View {
        content.background(GeometryReader { geo in
            Color.clear.preference(key: TouchRegionKey.self,
                                   value: [TouchRegion(target: target, frame: geo.frame(in: .named(PanelView.coordinateSpace)), z: z, clip: clip)])
        })
    }
}

extension View {
    func touchTarget(_ target: TouchTarget, z: Int = 0) -> some View {
        modifier(TouchTargetModifier(target: target, z: z))
    }

    /// Plan 4 §8.1: a pill that cannot act registers no region, so a tap on it falls through to what is under it.
    @ViewBuilder func touchTarget(_ target: TouchTarget, z: Int = 0, when enabled: Bool) -> some View {
        if enabled { touchTarget(target, z: z) } else { self }
    }
}
