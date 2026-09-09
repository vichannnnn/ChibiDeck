import AppKit
import Observation
import PanelCore
import os

let panelLog = Logger(subsystem: "me.himaa.chibideck", category: "app")

@MainActor @Observable
final class AppModel {
    let settings: PanelSettings
    let ui: PanelUIState
    let themes: [Theme]
    let mascots: [String: Mascot]
    /// Plan 3 §6: Terminal.app actions. `actions` is the protocol view that `perform` and the sheet use.
    let bridge: TerminalBridge
    var actions: PanelActions { bridge }
    /// Handoff §6: the one-per-pid sequences behind the menu's Handoff row.
    let handoffs: HandoffRunner
    /// Plan 3 §7: what the left column's permission lines and the menu bar show.
    var permissions = PermissionState()
    /// Plan 3 §8.3: whether the statusline script carries the feed hook; nil until first checked.
    var feedInstalled: Bool?
    private var feedStatusTimer: Timer?
    let collector: DataCollector
    /// Plan 3 §5.3: the tappable regions the views last reported, in canvas coordinates.
    var touchRegions: [TouchRegion] = []

    init() {
        let ui = PanelUIState()
        let bridge = TerminalBridge()
        self.ui = ui
        self.bridge = bridge
        handoffs = HandoffRunner(actions: bridge, ui: ui)
        let loadedSettings = PanelSettings()
        let loadedThemes = (try? ThemeLibrary.loadAll()) ?? []
        let loadedMascots = Dictionary(uniqueKeysWithValues: ((try? MascotLibrary.loadAll()) ?? []).map { ($0.id, $0) })
        settings = loadedSettings
        themes = loadedThemes
        mascots = loadedMascots
        collector = DataCollector(settings: loadedSettings)
        // Resources are a packaging invariant: the app ships with them, so their absence at
        // runtime means a broken build, not a recoverable condition. Fail loudly rather than
        // let `currentTheme`/`currentMascot` trap moments later on an empty collection.
        if loadedThemes.isEmpty {
            panelLog.error("no themes loaded from the resource bundle")
            fatalError("ChibiDeck: no themes found in the resource bundle (Resources/Themes)")
        }
        if loadedMascots.isEmpty {
            panelLog.error("no mascots loaded from the resource bundle")
            fatalError("ChibiDeck: no mascots found in the resource bundle (Resources/Mascots)")
        }
    }

    var currentTheme: Theme {
        // `init` fatalErrors if `themes` is empty, so `themes[0]` here is safe.
        themes.first { $0.id == settings.themeId } ?? themes.first { $0.id == ThemeLibrary.defaultThemeId } ?? themes[0]
    }

    var currentMascot: Mascot {
        let theme = currentTheme
        if let mascot = mascots[theme.mascot] { return mascot }
        panelLog.error("theme \(theme.id) references unknown mascot \(theme.mascot)")
        return fallbackMascot
    }

    /// Deterministic fallback for a theme that references a mascot id absent from `mascots`:
    /// the default theme's mascot, else the mascot with the lowest id. `init` fatalErrors if
    /// `mascots` is empty, so both lookups below are guaranteed to resolve.
    private var fallbackMascot: Mascot {
        if let defaultMascotId = themes.first(where: { $0.id == ThemeLibrary.defaultThemeId })?.mascot,
           let mascot = mascots[defaultMascotId] {
            return mascot
        }
        return mascots[mascots.keys.sorted()[0]]!
    }

    func start() {
        collector.start()
        bridge.onPermissionChange = { [weak self] status in self?.permissions.automation = status }
        bridge.refreshPermission()
        refreshFeedStatus()
        feedStatusTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshFeedStatus() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.shutdown() }
        }
    }

    /// Plan 3 §9.3: a dirty burn index is written before the process ends.
    func shutdown() { collector.flush() }

    /// Plan 3 §8.3: reads `settings.json` (read-only) to find the statusline script and looks for the marker.
    func refreshFeedStatus() {
        guard let settings = try? Data(contentsOf: ClaudePaths.settingsFile),
              let path = StatuslineConfig.scriptPath(settingsJSON: settings, home: ClaudePaths.home.path),
              let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            feedInstalled = false
            return
        }
        feedInstalled = FeedInstallState.isInstalled(scriptText: text)
    }

    /// The installer runs in a Terminal window; re-check after the user has had time to answer.
    func refreshFeedStatus(after seconds: TimeInterval) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            refreshFeedStatus()
        }
    }

    /// Spec 2026-09-07 §2.6: a tap on the character moves to the next theme (character and colours together).
    /// Plan 4 §3.2: no toast; the colours changing is the feedback.
    func cycleTheme() {
        guard let next = ThemeLibrary.next(after: currentTheme.id, in: themes) else { return }
        settings.themeId = next.id
    }

    var selectedSession: Session? { ui.selectedSessionId.flatMap { collector.state.session(id: $0) } }

    func closeSheet() {
        ui.closeSheet()
        collector.selectedForDetail = nil
    }

    /// Plan 6 §5: how long the card menu stays open without a tap.
    static let menuTimeout: TimeInterval = 6
    var menuSession: Session? { ui.menuSessionId.flatMap { collector.state.session(id: $0) } }
    func closeMenu() { ui.closeMenu() }

    /// Character select §6: a screen with nine choices gets a little longer than the card menu's 6 s.
    static let characterSelectTimeout: TimeInterval = 10
    func closeCharacterSelect() { ui.closeCharacterSelect() }

    /// Handoff §3: the menu row's rule, with "already running" read from the runner.
    func canHandoff(_ session: Session) -> Bool {
        ActionAvailability.canHandoff(session, actionsAvailable: actions.isAvailable, running: session.pid.map(handoffs.isRunning) ?? false)
    }

    /// Plan 3 §5.4 and Plan 6 §5: the one place panel actions happen, for mouse clicks and Edge taps alike.
    func perform(_ target: TouchTarget) {
        ui.noteTouch()
        switch target {
        case .mascot:
            guard ui.characterSelectOpenedAt == nil else { return }    // Character select §3: the release click after the long press, or a tap under the backdrop
            cycleTheme()
        case .characterSelect:
            guard ui.selectedSessionId == nil, ui.menuSessionId == nil else { return }   // Character select §3: never over the sheet or the card menu
            ui.openCharacterSelect()
        case .characterPick(let id):
            defer { ui.closeCharacterSelect() }
            guard ui.characterSelectOpenedAt != nil, themes.contains(where: { $0.id == id }) else { return }
            settings.themeId = id                                      // Character select §6: the same persisted value tap-to-cycle writes
        case .characterSelectClose:
            ui.closeCharacterSelect()
        case .card(let id):
            guard ui.menuSessionId == nil else { return }               // Plan 6 §5: while a menu is open only its rows and backdrop act
            guard collector.state.session(id: id) != nil else { return }
            bridge.refreshPermission()
            ui.openSheet(for: id)
            collector.selectedForDetail = id
            collector.ensureDetail(for: id)
        case .sheetBackdrop:
            if ui.selectedSessionId != nil { ui.sheetOpenedAt = Date() }      // restart the auto-return countdown
        case .sheetBack:
            closeSheet()
        case .sheetDismiss:
            if let session = selectedSession { collector.dismiss(session) }
            closeSheet()
        case .sheetHide:
            if let session = selectedSession { collector.hide(session) }
            closeSheet()
        case .sheetPageUp:
            ui.sheetPage = max(0, ui.sheetPage - 1)
            ui.sheetOpenedAt = Date()                          // reading counts as using the sheet
        case .sheetPageDown:
            ui.sheetPage += 1                                  // the sheet clamps to its page count
            ui.sheetOpenedAt = Date()
        case .cardAnswer(let id):
            guard ui.menuSessionId == nil else { return }               // Plan 6 §5: a long press on the pill opened the menu; its release types nothing
            guard let session = collector.state.session(id: id), let pill = cardPill(for: session), !pill.opensSheet,
                  let first = answers(for: session).first else { return }      // Plan 4 §7: only a sending pill sends
            sendAnswer(first, to: session)
        case .sheetAnswer(let index):
            guard let session = selectedSession else { return }
            let options = answers(for: session)
            guard options.indices.contains(index) else { return }
            sendAnswer(options[index], to: session)
        case .sheetFocus:
            guard let session = selectedSession, ActionAvailability.canFocus(session, actionsAvailable: actions.isAvailable) else { return }
            run(successToast: nil) { await self.actions.focusTab(session) }
        case .sheetHandoff:
            guard let session = selectedSession, canHandoff(session) else { return }
            closeSheet()                                                   // Handoff §3: the toasts and the restarting card are the feedback
            handoffs.start(session)
        case .cardMenu(let id):
            guard ui.selectedSessionId == nil, collector.state.session(id: id) != nil else { return }   // Plan 6 §4: never over the sheet
            bridge.refreshPermission()
            ui.openMenu(for: id)
        case .menuClose:
            ui.closeMenu()
        case .menuFocus:
            defer { ui.closeMenu() }
            guard let session = menuSession, ActionAvailability.canFocus(session, actionsAvailable: actions.isAvailable) else { return }
            run(successToast: nil) { await self.actions.focusTab(session) }
        case .menuHandoff:
            defer { ui.closeMenu() }
            guard let session = menuSession, canHandoff(session) else { return }
            handoffs.start(session)                                        // Handoff §4: its own toasts, outside `run`'s in-flight guard
        case .menuDismiss:
            if let session = menuSession { collector.dismiss(session) }
            ui.closeMenu()
        case .menuHide:
            if let session = menuSession { collector.hide(session) }
            ui.closeMenu()
        }
    }

    /// Plan 4 §5.3: what the card pill and the sheet pills offer for a session right now.
    func answers(for session: Session) -> [Answer] {
        AnswerResolver.answers(status: session.status, waitingFor: session.waitingFor,
                               pending: collector.state.detail(for: session.sessionId).pending,
                               quickReplies: AnswerResolver.quickReplies(from: settings.quickReplies))
    }

    /// Plan 4 §5.3: the card's pill for a session — `Allow ↵`, `N opts ›` or the first quick reply; nil when nothing can be
    /// typed. `pending` counts only while the session is waiting, so the label and the answers agree (Task 7 ruling).
    func cardPill(for session: Session) -> AnswerResolver.CardPill? {
        guard ActionAvailability.canAnswer(session, actionsAvailable: actions.isAvailable) else { return nil }
        let pending = session.status == .waiting ? collector.state.detail(for: session.sessionId).pending : nil
        return AnswerResolver.cardPill(answers: answers(for: session), pending: pending)
    }

    /// How long a second answer for the same session is refused after one was sent (a double tap must not type twice).
    static let answerCooldown: TimeInterval = 5
    private var lastAnswer: (sessionId: String, at: Date)?

    /// Plan 4 §5.3: the one send path for the card pill and the sheet pills. The cooldown is stamped only when `run`
    /// accepted the action, so a tap the in-flight guard dropped does not burn the next 5 s (final review).
    private func sendAnswer(_ answer: Answer, to session: Session) {
        guard ActionAvailability.canAnswer(session, actionsAvailable: actions.isAvailable) else { return }
        if let last = lastAnswer, last.sessionId == session.sessionId, Date().timeIntervalSince(last.at) < Self.answerCooldown { return }
        if run(successToast: "sent \(answer.label)", { await self.actions.sendLine(session, text: answer.text) }) {
            lastAnswer = (session.sessionId, Date())
        }
    }

    /// True from the moment an action starts until its result has been turned into a toast; a second tap in that
    /// window is dropped rather than queued behind the first AppleScript.
    private var actionInFlight = false

    /// Runs one action and turns its result into the panel toast (spec 2026-09-06 §6: `sent <label>`, or the failure text).
    /// One action at a time: `cardAnswer`/`sheetAnswer` and `sheetFocus` share the guard. Returns false when that guard
    /// dropped the action, which is how `sendAnswer` knows not to stamp the cooldown.
    @discardableResult
    private func run(successToast: String?, _ operation: @escaping @MainActor () async -> ActionResult) -> Bool {
        guard !actionInFlight else { return false }
        actionInFlight = true
        Task { @MainActor in
            switch await operation() {
            case .done: if let successToast { ui.toast = successToast }
            case .unavailable(let why), .failed(let why): ui.toast = why
            }
            actionInFlight = false
        }
        return true
    }
}
