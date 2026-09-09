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

extension View {
    /// Registers this view's frame (in `PanelView.coordinateSpace`, i.e. canvas points) as a touch region.
    func touchTarget(_ target: TouchTarget, z: Int = 0) -> some View {
        background(GeometryReader { geo in
            Color.clear.preference(key: TouchRegionKey.self,
                                   value: [TouchRegion(target: target, frame: geo.frame(in: .named(PanelView.coordinateSpace)), z: z)])
        })
    }

    /// Plan 4 §8.1: a pill that cannot act registers no region, so a tap on it falls through to what is under it.
    @ViewBuilder func touchTarget(_ target: TouchTarget, z: Int = 0, when enabled: Bool) -> some View {
        if enabled { touchTarget(target, z: z) } else { self }
    }
}
