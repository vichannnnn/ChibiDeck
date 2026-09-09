import SwiftUI

/// The panel is always laid out at 2560×720 points and scaled uniformly into whatever space it gets.
struct PanelScaler<Content: View>: View {
    static var canvasSize: CGSize { CGSize(width: 2560, height: 720) }
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / Self.canvasSize.width, geo.size.height / Self.canvasSize.height)
            ZStack {
                content()
                    .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
                    .scaleEffect(scale)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
