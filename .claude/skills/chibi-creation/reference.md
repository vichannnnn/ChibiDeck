# Chibi creation — reference

## The rig in one screen

| Piece | Where | What it gives a recipe |
|---|---|---|
| Donor sprites | `Scripts/mascots/sources/*.json` | The author's own pixel art the rig cuts parts from: `hi-bit-shoujo` (body, face, faces, flared long cut), `micro-hima` (chin bob), `sprite-shoujo` (shoulder bob), `rowena-rig` (long straight hair), `twintail-hima` (twintails, sailor collar), `mage` |
| `rig.py` | role maps, `Part`, `Recipe`, `bend`/`wag`, faces, hop, sparkles, `build_sprite`, `validate`, `dumps` | `hair_from(donor)`, `blank()`, `paste_grid(dst, lines, legend, x0, y0)`, `mirror(lines)`, `segments(row)`, `COLS`=68, `ROWS`=67 |
| `parts.py` | shared building blocks | `body_with_skull()`, `base_colours(**over)` (the family skin, outline, ink and face lines), `ACC` legend, `erase_rows`, `erase_box`, `remap_below` (gradient tips), `holes` |
| `characters.py` | Mage + the `RECIPES` registry | `RECIPES` order = tap order; the chibi roster is appended from `chibi/__init__.py` |
| `chibi/<id>.py` | one module per character | `recipe() -> Recipe`; the docstring is the design and its revision history |
| `build.py` | `build`, `check`, `render`, `docs` | stdlib for build/check; Pillow for render/docs |
| `render.py` | review images | `sheet` (all frames at 3×), `gif` (both tiers side by side), `loop_gif` (one transparent box, `<id>-loop.gif`, the README header), `contact` (cruise[0] of every mascot at 280 px), `roster` (the README grid) |

`Recipe(id, name, colours, body, front=[...], back=[...])`: `back` parts draw behind the body (tails, capes, wings,
a mask tucked behind the hair), the body next, `front` parts over it in order, then the face, then the hop and the
sparkles of the `top` tier.

`Part(grid, motion="bend", root=12, bottom=None, scale=1.0, cap=None, stretch=True, nod=None)`:

- `bend` — a smooth bend from `root` (no motion) towards `bottom` (full amplitude). Hair: `root=12`. Capes and
  skirts: `root=41`, `scale=0.5`, `cap=2`. Ribbons: `scale=0.5`, `cap=2`, `stretch=False`.
- `stretch=True` keeps the inner edge of a lock lying against the body and stretches it, so no slit opens.
  `stretch=False` slides the whole segment: free twintails, hanging ribbons.
- `wag` — vertical sway rooted at the end nearest the body axis: tails, wings.
- `rigid` — hats, buns, pins, a held card or microphone. `nod=False` keeps a torso-held prop still while the head nods;
  `nod=True` lets a `back` part follow the head.

## The accessory legend (`parts.ACC`)

`o` outline · `l` hair_light · `m` hair_mid · `s` hair_shadow · `d` hair_deep · `D` hair_deeper · `i` ear_inner ·
`w` tail_tip · `W` eye_white · `P` dress_shade · `S` dress_trim · `E` ribbon_light · `M` ribbon_mid · `F` ribbon_dark ·
`g` skin · `e` blush · `k` ink · `A` accent_a · `B` accent_b. `.` is transparent. Extend it per recipe with
`dict(ACC, R="dress_white")`. `accent_a` and `accent_b` are free roles a recipe colours as it likes; a green scarf or
an orange streak lives there.

Grids are drawn as text, one string per row, and pasted at `(x0, y0)`; `mirror()` flips a grid for the other side.

## Hard rules (the build or `check` enforces these)

- 68×67, ≤ 16 colours. Roles sharing a hex share a slot, so a budget is met by giving pupils, shoes or an outline the
  `ink` colour, not by dropping detail. Every shipped chibi lands on exactly 16, so a new one plans its sharing first.
- Two tiers, `cruise` and `top`, eight frames each. The face is stamped from the templates: smile in every frame,
  eyes open except the blink on `cruise[3]`. Nothing may cover the eyes (rows 31–36, cols 23–42) or the mouth
  (rows 38–39, cols 30–36).
- `accent_a` and `accent_b` have no default in `base_colours()`: a grid that uses them needs both hexes passed, or the
  build stops with `no colour for roles [...]`.
- Rows 0–1 empty: `top` lifts odd frames by 2 px and refuses a frame that would clip.
- Enclosed transparent pockets ≤ 4 px are healed automatically; bigger ones are visible holes and the recipe's problem.
- The JSON text must equal `rig.dumps(build_sprite(recipe()))`; every theme must name a built mascot.

## Motion rules (the user's standard; not enforced by code)

- One motion model, the bend: amplitude 2 px, lean 1 px in `cruise` and `top`; adjacent rows never differ by more
  than 1 px; the loop is seamless. Amplitudes stay ≤ 4 px after `scale`. The first roster's per-row wave (10 px tips,
  notched edges, a still copy of the hair behind the body) was rejected as "moving weirdly": never draw a static copy
  behind a moving part, never move rows independently.
- The head (rows 0–40), hair and front parts nod 1 px down on frames 4–7; the torso and back parts stay.
- "Refined and detailed" means: shine strokes on the crown, thin strand lines in flat hair planes, the signature
  accessory in three tones with an outline and an interior detail, one secondary motion per character (ribbon, tail,
  ears, wings, cape), a dress detail in the trim role.

## Review checklist (run on the sheet before the user sees anything)

- R1 Silhouette reads at 280 px on the theme background (`contact.png`): head, hair shape and one accessory
  recognisable at arm's length.
- R2 Smile in all 16 frames, eyes open in `top`; the blink only on `cruise[3]`.
- R3 No holes: no background shows through body, face or dress in any frame; no stray pixels outside the outline
  except sparkles.
- R4 Motion visible but small: hair tips move ≥ 3 px across the loop; the fringe never exposes more than 2 px of
  forehead beyond the still frame.
- R5 Seamless loop: frame 7 → 0 has no jump larger than any other step.
- R6 Palette: ≤ 16 colours; outline and ink darker than the theme's `card`; hair light tone lighter than the theme's
  `muted`; the theme accent distinct from the neighbouring themes' accents.

Reading `<id>-sheet.png`: both tiers, every frame at 3×. `cruise[3]` is the blink; `cruise[4..7]` carry the nod;
odd frames of `top` are the hop with sparkles. `<id>.gif` plays both tiers side by side at 4 fps; `<id>-loop.gif` is
the single transparent box the README header uses, the closest thing to the panel. `contact.png` holds only the
mascots of the last `render` call, so render everything before judging R1 and R6.

The design notes the code comments cite ("spec §N", "roster spec §N") are kept outside the repo; this checklist and
the motion rules above are the in-repo version of them.

## Theme JSON

One line, keys in this order: `id`, `name`, `mascot`, `order`, `background`, `card`, `line`, `accent`, `text`,
`muted`. Backgrounds are near-black tints of the character's colour (`#0C0D17` … `#180A0A`), `card` a step lighter,
`line` two steps, `accent` the character's signature colour at full saturation, `text` near white, `muted` a grey of
the same hue. Example: `{"id":"lantern-red","name":"Lantern Red","mascot":"ruby","order":1,"background":"#180A0A","card":"#241012","line":"#3D1E1F","accent":"#FF6B5A","text":"#FBEDE8","muted":"#8E7C79"}`.
Set it live with `defaults write me.himaa.chibideck themeId <theme-id>` and relaunch.

## Every file a new character touches

| File | Change |
|---|---|
| `Scripts/mascots/chibi/<id>.py` | new recipe module |
| `Scripts/mascots/chibi/__init__.py` | import, `ROSTER`, docstring order line |
| `Sources/PanelCore/Resources/Themes/<theme-id>.json` | new theme |
| `Sources/PanelCore/Resources/Mascots/<id>.json` | written by `build.py build` |
| `Scripts/mascots/test_characters.py` | `spec_order` |
| `Tests/PanelCoreTests/MascotLoaderTests.swift` | the id set |
| `Tests/PanelCoreTests/ThemeLoaderTests.swift` | the ordered id list, `themes.count`, the wrap-around expectation |
| `Tests/PanelCoreTests/PanelResourcesTests.swift` | `themes.count` |
| `README.md` | the count in the roster image's alt text, the "Tap order" line |
| `Scripts/mascots/README.md` | the count in the `build` usage line, the module range in "How it works" |
| `docs/images/roster.png`, `docs/images/mage.gif` | `python3 Scripts/mascots/build.py docs` (three columns; a tenth mascot starts a fourth row alone, which is fine) |

Changing an existing character touches only its recipe, its JSON (rebuilt) and, when the look changes, the roster image.
