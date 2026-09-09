import SwiftUI
import PanelCore

/// Plan 3 §4: the only SwiftUI scene is the menu bar item. The panel and the preview are AppKit windows owned by
/// `PanelController`, so nothing opens at launch except what `EdgeScreenLocator` decides.
@main
struct ChibiDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Chibi Deck", systemImage: "display") {
            MenuContent(panels: appDelegate.panels).environment(appDelegate.model)
        }
    }
}

/// Plan 3 §7: Show Preview · Theme · Auto-dim · feed status · touch permission · Terminal automation · Quit.
struct MenuContent: View {
    @Environment(AppModel.self) private var model
    let panels: PanelController

    var body: some View {
        Button("Show Preview") { panels.showPreview() }
            .onAppear { model.refreshFeedStatus() }      // Plan 3 §8.3: the feed status is re-read when the menu opens
        Divider()
        Menu("Theme") {
            ForEach(model.themes) { theme in
                Button {
                    model.settings.themeId = theme.id
                } label: {
                    if theme.id == model.settings.themeId { Text("✓ \(theme.name)") } else { Text(theme.name) }
                }
            }
        }
        Toggle("Auto-dim after \(model.settings.autoDimMinutes) min", isOn: Binding(
            get: { model.settings.autoDimEnabled }, set: { model.settings.autoDimEnabled = $0 }))
        Toggle("Show in Dock", isOn: Binding(get: { model.settings.showInDock }, set: { model.settings.showInDock = $0 }))
        Button("Unhide all sessions") { model.collector.unhideAll() }
            .disabled(model.collector.state.hiddenByUser == 0)
        Divider()
        if model.feedInstalled == true {
            Text("Statusline feed: installed")
        } else {
            Button("Install statusline feed…") {
                ScriptLocator.openInTerminal(ScriptLocator.installStatusline)
                model.refreshFeedStatus(after: 20)
            }
        }
        switch model.permissions.inputMonitoring {
        case .granted:
            Text("Touch: ok")
        case .denied, .notDetermined:
            Button("Open Input Monitoring settings…") { AutomationPermission.openInputMonitoringSettings() }
        case .unknown:
            Text("Touch: waiting for the Edge")
        }
        if model.permissions.automation == .denied {
            Button("Open Automation settings…") { AutomationPermission.openAutomationSettings() }
        } else {
            Text("Terminal automation: ok")
        }
        Divider()
        Button("Quit Chibi Deck") { NSApp.terminate(nil) }
    }
}
