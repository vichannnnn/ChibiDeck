# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ChibiDeck: a native macOS menu-bar app that turns the Corsair Xeneon Edge (2560×720 touchscreen) into a status panel for the Claude Code sessions running on this Mac. Sessions, limits, a 24 h token-burn chart, a pixel-art mascot, and tap actions (focus the Terminal tab, send an answer, dismiss, hide). No server, no browser, no network: everything is read from `~/.claude` and `claude agents --json`. Swift 6 / SwiftPM, macOS 15+, SwiftUI inside AppKit windows.

Until 2026-09-08 the app was called `CorsairDisplay` (bundle id `me.himaa.corsairdisplay`). The rename is complete: the user-facing name is "Chibi Deck" (bundle `Chibi Deck.app`, CFBundleName, menu strings; the executable and targets stay `ChibiDeck`), bundle id `me.himaa.chibideck`, LaunchAgent label, Application Support folder, log subsystem and the feed marker `# chibideck-feed`. Three migrations keep an old install working: `AppDelegate` moves the old Application Support folder and copies the old `UserDefaults` domain on first launch, `install.sh` retires the old LaunchAgent and app copy, and `install-statusline.sh` replaces an old `# corsairdisplay-feed` hook line. TCC grants (Input Monitoring, Automation) are keyed on the bundle id and must be granted again.

## Commands

```bash
swift build                                   # debug build
swift run ChibiDeck                           # runs from the menu bar; with no Edge attached it opens the preview window
swift test                                    # all PanelCore tests (swift-testing, not XCTest)
swift test --filter TouchTests                # one suite
swift test --filter TouchTests/parsesDownMoveUp   # one test
Scripts/test-install-statusline.sh            # shell test for the statusline installer (throwaway HOME)
python3 -m unittest discover -s Scripts/mascots -p 'test_*.py'   # mascot rig tests
python3 Scripts/mascots/build.py check        # mascot JSON matches the recipes; run before committing Resources/Mascots or Themes

Scripts/bundle.sh                             # release build → "build/Chibi Deck.app" + build/ChibiDeck-<version>.zip, signed (IDENTITY, VERSION env vars)
python3 Scripts/icon/make-icon.py             # regenerate Resources/ChibiDeck.icns (macOS 15 tile) and Resources/ChibiDeck.icon (macOS 26; bundle.sh compiles it with Xcode's actool)
Scripts/install.sh [--statusline]             # copy to ~/Applications, LaunchAgent, start; --uninstall, --dry-run
```

Release builds pass `-Xswiftc -disable-cmo`: Swift 6.3.3 crashes in cross-module optimisation on this package. Keep the flag in `bundle.sh` until the toolchain is fixed.

Watching the running app from a shell: `log` is a zsh builtin, so use `/usr/bin/log stream --predicate 'subsystem == "me.himaa.chibideck"' --style compact --info`. Only the bundled app can be quit cleanly (`osascript -e 'tell application id "me.himaa.chibideck" to quit'`); `pkill` skips the burn-index flush. Set the theme for a capture with `defaults write me.himaa.chibideck themeId <id>` rather than tapping the mascot.

## Architecture

Two targets with a hard line between them:

- **`PanelCore`** (library): pure logic, no AppKit, fully unit-tested. Models, parsers for every Claude Code file format, touch recognisers, and the `Logic/` resolvers. Everything that can be a pure function lives here, including the AppleScript text (`TerminalScripts`) and the text pager for the detail sheet, so the app target only executes strings and draws results.
- **`ChibiDeck`** (executable): the AppKit/SwiftUI shell. Owns timers, FSEvents, the HID reader, windows and Apple Events. New behaviour goes into `PanelCore` first with a test; the app target wires it.

Data flow, all on the main actor:

1. `DataCollector` gathers `RawInputs`: `claude agents --json` every 5 s, `~/.claude/sessions/<pid>.json` and the statusline feed via FSEvents, `~/.claude.json` limits cache, `stats-cache.json`, job state files for background agents, transcript tails, task lists, git branch per cwd. `BurnIndexer` walks transcripts under `~/.claude/projects` on its own queue every 60 s with persisted byte offsets.
2. `StateBuilder.build(inputs, now:)` (PanelCore) turns `RawInputs` into one immutable `PanelState`: ageing, hidden/dismissed, sorting and the 8-card cap, attention counts, mascot pose, limit forecasts, burn buckets. Views only read `PanelState`.
3. `AppModel` owns the collector, settings, themes, mascots, the `TerminalBridge` and the list of touch regions. Every action, from mouse or touch, goes through `AppModel.perform(_ target: TouchTarget)`; `ActionAvailability` decides what is allowed.

Rendering: `PanelView` is always laid out at 2560×720 points and `PanelScaler` scales it into whatever window it gets. `PanelWindow` is the borderless, never-key window on the Edge; `PreviewWindowController` shows the same content on the main screen at half size. `EdgeScreenLocator` plus `EdgeScreenMatch` decide which exists. Type is SF Mono only, nothing under 17 pt.

Touch: `HIDTouchReader` seizes the Edge's mouse HID interface (vendor 0x27C0, product 0x0859, report id 7, single touch only on macOS) and needs Input Monitoring. In `HIDTouchReader.start()` the order Open then Activate is load-bearing: the reverse crashes when the Edge is already attached at launch. `TouchDispatcher` runs the report parser, `TapRecognizer` and `LongPressRecognizer`, maps raw units to canvas points (`CoordinateMapper`, calibrated by `touchOffset*`/`touchScale*` defaults) and hit-tests the regions every tappable view publishes with `.touchTarget(...)` (`HitTester`: highest z wins, then last registered). Mouse and touch therefore share one path and one set of targets.

Actions: `TerminalBridge` resolves a session's pid to a tty with `ps`, then drives Terminal.app by AppleScript to select that tab and type an answer. Background agents have no tty and no channel. A Handoff row in the card menu types `/handoff`, waits for the skill's reply in the transcript, types `/clear` and pastes the block back into the same tab (`HandoffSequencer` in PanelCore, `HandoffRunner` in the app; `TerminalScripts.paste` keeps line breaks, which Claude Code takes as one pasted message).

Statusline feed: Claude Code's own statusline script gets one marked line (`Scripts/install-statusline.sh`, idempotent, shows a diff and asks) that mirrors each statusline payload to `~/Library/Application Support/ChibiDeck/statusline/<session_id>.json`. That feed is where context-window size, cost and live rate limits come from. The app never edits the statusline script itself and never writes under `~/.claude`; its only writable location is its Application Support folder.

Resources: themes (`Resources/Themes/*.json`, one per mascot, `order` is the tap order) and mascots (`Resources/Mascots/*.json`, 16-colour run-packed sprites with two tiers, `cruise` and `top`; the other poses fall back to `cruise`) are loaded through `PanelResources`, which knows the three places the bundle can be at runtime (`.app/Contents/Resources`, next to a `swift run` binary, `Bundle.module` under tests). Mascot JSON is generated by `Scripts/mascots/build.py` from recipes (`characters.py` for Mage, one module per character under `Scripts/mascots/chibi/`); do not hand-edit it (see `Scripts/mascots/README.md`). Adding a mascot means a recipe module, a theme file and updating the id lists in `MascotLoaderTests`, `ThemeLoaderTests` and `test_characters.py`.

## Skills

`.claude/skills/` ships two project skills: `handoff` (the prompt the panel's Handoff action asks a session to write; keep it a verbatim copy of the user's skill) and `chibi-creation` (adding or changing a mascot with the rig under `Scripts/mascots`). `Scripts/install.sh --skills` copies them into `~/.claude/skills` without overwriting existing names. When the mascot workflow changes, update the skill with it.

## Specs, plans and comments

Work is spec-driven. `docs/superpowers/specs/` holds the approved designs and `docs/superpowers/plans/` the implementation plans, dated. That folder is gitignored (local working notes, not part of the published repo), so never rely on it being present in a fresh clone. Later specs amend earlier ones and say which sections they supersede. Code comments cite them (`Plan 4 §5.3`, `spec 2026-09-07 §2.4`); when you change behaviour that a comment ties to a section, keep the citation truthful. Non-obvious decisions and verified platform facts (HID report shape, file formats, Terminal behaviour) are recorded in the specs, not rediscovered.

Limits data comes from the local cache and the statusline feed only. Do not add calls to the OAuth usage endpoint.
