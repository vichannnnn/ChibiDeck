#!/usr/bin/env python3
"""Build, check or render the panel mascots (spec 2026-09-08 §7).

  python3 Scripts/mascots/build.py build [id ...]    write Sources/PanelCore/Resources/Mascots/<id>.json
  python3 Scripts/mascots/build.py check             rebuild in memory and compare with the checked-in files
  python3 Scripts/mascots/build.py render [id ...]   review images under build/mascots/ (needs Pillow)
  python3 Scripts/mascots/build.py docs              docs/images/roster.png and mage.gif for the README (needs Pillow)
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import rig            # noqa: E402
import characters     # noqa: E402

ROOT = HERE.parent.parent
MASCOTS = ROOT / "Sources/PanelCore/Resources/Mascots"
THEMES = ROOT / "Sources/PanelCore/Resources/Themes"
OUT = ROOT / "build/mascots"
DOCS = ROOT / "docs/images"


def selected(args):
    ids = args or list(characters.RECIPES)
    unknown = [i for i in ids if i not in characters.RECIPES]
    if unknown:
        raise SystemExit(f"unknown mascot id(s) {unknown}; known: {list(characters.RECIPES)}")
    return ids


def cmd_build(ids):
    MASCOTS.mkdir(parents=True, exist_ok=True)
    for sid in ids:
        sprite = rig.build_sprite(characters.RECIPES[sid]())
        (MASCOTS / f"{sid}.json").write_text(rig.dumps(sprite), encoding="utf-8")
        print(f"wrote {sid}.json: {len(sprite['palette'])} colours, "
              + " ".join(f"{t}x{len(sprite['tiers'][t])}" for t in rig.TIERS))
    return 0


def cmd_check():
    errs, built = [], set()
    for sid, recipe in characters.RECIPES.items():
        try:
            text = rig.dumps(rig.build_sprite(recipe()))
        except Exception as e:                      # a recipe bug (KeyError, IndexError …) is a check failure, not a crash
            errs.append(f"{sid}: {e}" if isinstance(e, ValueError) else f"{sid}: {type(e).__name__}: {e}")
            continue
        built.add(sid)
        path = MASCOTS / f"{sid}.json"
        if not path.exists():
            errs.append(f"{sid}: {path.relative_to(ROOT)} is missing (run build)")
        elif path.read_text(encoding="utf-8") != text:
            errs.append(f"{sid}: {path.relative_to(ROOT)} differs from the rig output (run build)")
    for path in sorted(MASCOTS.glob("*.json")):
        if path.stem not in characters.RECIPES:
            errs.append(f"{path.relative_to(ROOT)} has no recipe in characters.py")
    for path in sorted(THEMES.glob("*.json")):
        mascot = json.loads(path.read_text(encoding="utf-8")).get("mascot")
        if mascot not in built:
            errs.append(f"{path.relative_to(ROOT)} references mascot {mascot!r}, which is not built")
    if errs:
        print("CHECK FAILED:\n  " + "\n  ".join(errs))
        return 1
    print(f"ok: {', '.join(sorted(built))} match the rig output; themes reference built mascots")
    return 0


def cmd_render(ids):
    import render
    OUT.mkdir(parents=True, exist_ok=True)
    sprites = []
    for sid in ids:
        sprite = rig.build_sprite(characters.RECIPES[sid]())
        theme = render.theme_for(sid, THEMES)
        render.sheet(sprite, OUT / f"{sid}-sheet.png")
        render.gif(sprite, theme, OUT / f"{sid}.gif")
        render.loop_gif(sprite, theme, OUT / f"{sid}-loop.gif")
        sprites.append((sprite, theme))
        print(f"wrote {sid}-sheet.png, {sid}.gif and {sid}-loop.gif")
    render.contact(sprites, OUT / "contact.png")
    print(f"wrote contact.png in {OUT.relative_to(ROOT)}")
    return 0


def cmd_docs():
    """The README images: the roster grid, and the default mascot's two tiers looping at 240 px."""
    import render
    DOCS.mkdir(parents=True, exist_ok=True)
    sprites = [(rig.build_sprite(recipe()), render.theme_for(sid, THEMES)) for sid, recipe in characters.RECIPES.items()]
    render.roster(sprites, DOCS / "roster.png")
    first, theme = sprites[0]
    render.loop_gif(first, theme, DOCS / f"{first['id']}.gif")
    print(f"wrote roster.png and {first['id']}.gif in {DOCS.relative_to(ROOT)}")
    return 0


def main(argv):
    if len(argv) < 2 or argv[1] not in ("build", "check", "render", "docs"):
        print(__doc__)
        return 2
    if argv[1] == "build":
        return cmd_build(selected(argv[2:]))
    if argv[1] == "check":
        return cmd_check()
    if argv[1] == "docs":
        return cmd_docs()
    return cmd_render(selected(argv[2:]))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
