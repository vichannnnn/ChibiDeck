import SwiftUI
import PanelCore

/// Plan 6 §4: the menu a long hold opens over a card — Focus tab · Handoff (Handoff §3) · Dismiss · Hide. Each row is a `Button` for the mouse and
/// a z 3 touch region for the Edge; a disabled row is drawn at 40 % and registers nothing (Plan 4 §8.1). The backdrop
/// that closes the menu and the 6 s timer live in `PanelView`.
struct CardMenu: View {
    @Environment(\.palette) private var palette
    @Environment(AppModel.self) private var model
    let session: Session

    static let width: CGFloat = 348
    static let rowHeight: CGFloat = 60
    static let height: CGFloat = 4 * rowHeight + 3 * 2

    var body: some View {
        VStack(spacing: 0) {
            row("Focus tab", target: .menuFocus, enabled: ActionAvailability.canFocus(session, actionsAvailable: model.actions.isAvailable))
            Rectangle().fill(palette.line).frame(height: 2)
            row("Handoff", target: .menuHandoff, enabled: model.canHandoff(session))
            Rectangle().fill(palette.line).frame(height: 2)
            row("Dismiss", target: .menuDismiss)
            Rectangle().fill(palette.line).frame(height: 2)
            row("Hide", target: .menuHide)
        }
        .frame(width: Self.width)
        .background(palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.accent, lineWidth: 2))
        .shadow(color: .black.opacity(0.5), radius: 20)
    }

    private func row(_ title: String, target: TouchTarget, enabled: Bool = true) -> some View {
        Button(action: { model.perform(target) }) {
            HStack {
                Text(title).font(PanelType.mono(24, .bold)).foregroundStyle(palette.text)
                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(height: Self.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .touchTarget(target, z: 3, when: enabled)
    }
}
