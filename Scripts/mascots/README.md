# Mascot rig

The panel mascots (`Sources/PanelCore/Resources/Mascots/*.json`) are **built**, not hand-edited. The design notes (mascot spec and chibi roster spec, kept outside the repo) describe the motion model; the roster adds the chibi characters and the bend motion model on the same rig, and its §6 cuts the animation down to two tiers.

```
python3 Scripts/mascots/build.py build [id ...]    write the JSON (all nine when no id)
python3 Scripts/mascots/build.py check             rebuild in memory, compare with the checked-in files, verify faces and themes
python3 Scripts/mascots/build.py render [id ...]   build/mascots/<id>-sheet.png, <id>.gif, <id>-loop.gif, contact.png (needs Pillow)
python3 Scripts/mascots/build.py docs              docs/images/roster.png and mage.gif for the README (needs Pillow)
python3 -m unittest discover -s Scripts/mascots -p 'test_*.py'
```

`build` and `check` need only the Python 3 standard library. Run `check` before committing anything under `Resources/Mascots` or `Resources/Themes`.

## How it works

- `sources/` holds the donor sprites (the author's own pixel art) the rig cuts parts from: hi-bit-shoujo (face, body, faces), micro-hima (chin bob), sprite-shoujo (shoulder bob), rowena-rig (long straight hair), twintail-hima (sailor collar), mage.
- `rig.py` turns a donor frame into a role map (one semantic role per pixel: `hair_mid`, `skin`, `dress_shade`, …), composes layers per frame in this order — the recipe's `back` parts (a tail), the body with its skull, the `front` parts (hair and accessories), the face, the top pose's hop and sparkles — applies the bend motion of the roster spec §3 (a smooth bend from the root, a 1-px head nod, hole healing) and the face set of spec §5, and packs the result with a `role -> hex` table into the sprite JSON (≤ 16 colours; roles sharing a colour share a slot).
- `parts.py` holds what every recipe shares: the hima-family colour defaults, the body with its skull, the accessory legend `ACC`, and layer helpers (`erase_rows`, `erase_box`, `remap_below` for gradient tips, `holes` for the R3 count).
- `characters.py` holds Mage and the `RECIPES` registry, which is the tap order; `chibi/` holds one module per roster character (`ruby.py` … `rosalie.py`, each with a `recipe()`), registered by `chibi/__init__.py`.
- Two tiers are built (roster spec §6): `cruise`, the eight-frame hair-wave loop the panel shows in every state, and `top`, the same loop lifted 2 px on odd frames with sparkles, shown while a session waits for the user. Rows 0–1 of a recipe must stay empty for that hop; the build refuses a frame the hop would clip.
- `Recipe.back` parts live behind the body (tails, props, capes, wings); `front` parts are drawn over it in order. A lock against the body stretches from its inner edge instead of sliding, so no slit opens and no still copy is needed.

## Adding a character

1. Write `Scripts/mascots/chibi/<id>.py` with a `def recipe() -> Recipe` (module docstring = the design): start from `body_with_skull()`, pick a hair with `hair_from(donor)`, draw accessories as text grids (legend `ACC`), give every role a colour with `base_colours(...)`, and list the moving parts as `Part(...)` (`bend` for hair and hanging cloth — `stretch=False` for free twintails — `wag` for a tail or wing, `rigid` for hats and pins; `nod=False` keeps a hand-held prop with the torso).
2. Add the module to `chibi/__init__.py` (`ROSTER` is the tap order) and a theme JSON to `Resources/Themes` (`order` = tap position).
3. `build`, `render`, look at the sheet against spec §9, `check`, then update the id lists in `MascotLoaderTests`, `ThemeLoaderTests` and `test_characters.py`.

## Reading the review sheet

`<id>-sheet.png` shows every frame of both tiers at 3×. Frame 3 of cruise is the blink; frames 4–7 carry the 1-px nod; odd frames of top are the hop. `<id>.gif` plays the two tiers side by side at 4 fps; `<id>-loop.gif` is the transparent single-box loop the README header uses (`docs/images/mage.gif`). `contact.png` shows `cruise[0]` of every rendered mascot at the panel's 280 px on its theme background.
