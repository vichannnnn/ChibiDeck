---
name: chibi-creation
description: Use when the user asks for a new chibi, a new mascot or a new character for the Chibi Deck panel, or wants an existing mascot's hair, outfit, accessory, colours, motion or theme changed. Also when a mascot JSON, theme JSON or roster image needs regenerating.
---

# Chibi creation

## Overview

Every panel mascot is **built by the rig in `Scripts/mascots`**, never drawn by hand: a Python recipe composes a shared
body, a donor hair cut and text-grid accessories into a 68×67, ≤ 16-colour sprite with two 8-frame animations. The
checked-in JSON must match the recipe byte for byte. Motion quality is judged before art detail: the user notices
tearing, ghosting and over-swing at once.

**REQUIRED BACKGROUND:** read `Scripts/mascots/README.md` and one recipe under `Scripts/mascots/chibi/` before writing
anything. `reference.md` beside this file has the rules, the review checklist and the file list.

## Before drawing

Ask for the design if the user did not give it: hair (shape, colour), outfit, one signature accessory, the theme's mood.
The reference images the roster was designed from live outside the repo, so a description or an image from the user is
the source. Decide the id (kebab-case), the display name, the theme id and name (a flavour name like `rose-frost`, not
the colour), and the tap position (new characters go last unless told otherwise).

## Steps

1. **Recipe** `Scripts/mascots/chibi/<id>.py`: module docstring = the design in words; `recipe() -> Recipe` built from
   `body_with_skull()`, `hair_from(<donor>)`, `paste_grid` accessories with the `ACC` legend, `base_colours(...)`, and
   `Part(...)` entries: `bend` for hair and hanging cloth (`stretch=False` for free twintails), `wag` for tails and
   wings, `rigid` for hats and pins, `nod=False` for a prop held at the torso. Rows 0–1 stay empty (the hop).
2. **Register**: add the module to `Scripts/mascots/chibi/__init__.py` (`ROSTER` tuple, docstring order line).
3. **Theme** `Sources/PanelCore/Resources/Themes/<theme-id>.json`, one line, `"mascot":"<id>"`, `"order"` = tap position.
4. **Build and render**: `python3 Scripts/mascots/build.py build <id>` then `render` with no ids (`render <id>` is
   faster but leaves `contact.png` with that one mascot, and the checklist compares neighbours).
5. **Review the sheet yourself** (`build/mascots/<id>-sheet.png`, `<id>.gif`, `<id>-loop.gif`, `contact.png`) against
   the checklist in `reference.md` before showing anything. Fix and rebuild until it passes.
6. **Check**: `python3 Scripts/mascots/build.py check` and `python3 -m unittest discover -s Scripts/mascots -p 'test_*.py'`.
7. **Tests and docs**: id lists in `Tests/PanelCoreTests/MascotLoaderTests.swift`, `ThemeLoaderTests.swift`
   (list, count, wrap-around), `PanelResourcesTests.swift` (count) and `Scripts/mascots/test_characters.py`
   (`spec_order`); the tap-order line and mascot count in `README.md` and `Scripts/mascots/README.md`;
   `python3 Scripts/mascots/build.py docs` rewrites `docs/images/roster.png` and `mage.gif`. `swift test`.
8. **Show the user** `contact.png` and the sheet, one question: keep, tweak or redo. Expect rounds; each round is one
   commit (`feat: roster round N — <what changed>`).

`Scripts/icon/make-icon.py` stays untouched unless the default mascot (`ThemeLibrary.defaultThemeId`) changes.

## Common mistakes

| Mistake | Fix |
|---|---|
| Editing `Resources/Mascots/*.json` by hand | Change the recipe, run `build`; `check` fails otherwise |
| Showing the user before opening the sheet | Look at every frame first; the hop, blink and nod are on specific frames |
| A pixel in rows 0–1 | The build refuses the `top` tier; move the hat or ahoge down |
| A 17th colour | Every shipped chibi already uses all 16, so plan the sharing from the start: two roles with the same hex share a slot; pupils and shoes take `ink` |
| `no colour for roles ['accent_a']` | `base_colours()` has no default for `accent_a`/`accent_b`; pass a hex for every role a grid uses |
| Accessory over the face (eyes rows 31–36 × cols 23–42, mouth rows 38–39 × cols 30–36) | The face check fails; hide the part behind the hair or move it |
| Motion looks "weird" | Amplitude, not detail: keep parts on `bend` with `scale`/`cap`, never a still copy behind a moving part |
