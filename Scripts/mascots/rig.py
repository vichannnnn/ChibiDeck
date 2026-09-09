#!/usr/bin/env python3
"""Sprite rig for the panel mascots (mascot design notes, kept outside the repo).

Standard library only. A donor frame becomes a ROLE MAP (a 67×68 grid of role names or None); a character
is built by pasting role-map layers (body, hair, accessories, face) per frame, and a `role -> hex` table packs
the result into the sprite JSON that MascotLoader reads (68×67, ≤ 16 colours, '.' = transparent).
"""
from __future__ import annotations

import json
import math
import re
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCES = HERE / "sources"
COLS, ROWS = 68, 67
# Round three (roster spec §6): one hair-wave loop per character. `cruise` is that loop and stands in for every
# panel state (Mascot.frames(for:) falls back to it); `top` is the "needs you" alert — the same loop with a 2-px hop on
# alternate frames and sparkles. sleep / bored / fast are no longer built.
TIERS = ["cruise", "top"]
FRAMES = {"cruise": 8, "top": 8}
# The 1-px head nod per frame (see build_frame): four frames up, four down.
NOD = {"cruise": [0, 0, 0, 0, 1, 1, 1, 1], "top": [0, 0, 0, 0, 1, 1, 1, 1]}
# The hop: the whole frame moves up by this many rows (rows 0..HOP-1 of a recipe must stay empty).
HOP = {"cruise": [0] * 8, "top": [0, 2] * 4}

# ---------------------------------------------------------------- grids

def load_source(sid: str) -> dict:
    """A donor sprite from sources/."""
    with open(SOURCES / f"{sid}.json", encoding="utf-8") as f:
        return json.load(f)


def blank() -> list:
    return [[None] * COLS for _ in range(ROWS)]


def copy(grid: list) -> list:
    return [row[:] for row in grid]


def paste(dst: list, src: list, dx: int = 0, dy: int = 0, only=None, skip=None) -> list:
    """Paste the non-None pixels of `src` onto `dst`, shifted by (dx, dy); `only`/`skip` filter by role prefix."""
    for r in range(ROWS):
        rr = r + dy
        if not 0 <= rr < ROWS:
            continue
        for c in range(COLS):
            v = src[r][c]
            if v is None:
                continue
            if only and not v.startswith(only):
                continue
            if skip and v.startswith(skip):
                continue
            cc = c + dx
            if 0 <= cc < COLS:
                dst[rr][cc] = v
    return dst


def paste_grid(dst: list, lines: list, legend: dict, x0: int, y0: int) -> list:
    """Paste a small text grid: legend maps a character to a role; '.' is transparent, '-' erases."""
    for dy, line in enumerate(lines):
        for dx, ch in enumerate(line):
            if ch == ".":
                continue
            rr, cc = y0 + dy, x0 + dx
            if 0 <= rr < ROWS and 0 <= cc < COLS:
                dst[rr][cc] = None if ch == "-" else legend[ch]
    return dst


def mirror(lines: list) -> list:
    return [line[::-1] for line in lines]


def bounds(layer: list):
    """(top, bottom, left, right) of the non-None pixels, or None for an empty layer."""
    rows = [r for r in range(ROWS) if any(v is not None for v in layer[r])]
    if not rows:
        return None
    cols = [c for c in range(COLS) if any(layer[r][c] is not None for r in rows)]
    return rows[0], rows[-1], cols[0], cols[-1]


# ---------------------------------------------------------------- roles (hima family)

HAIR_CHARS = {"A": "hair_light", "N": "hair_mid", "K": "hair_shadow", "L": "hair_deep", "C": "hair_deeper"}
EYE_ROWS, EYE_COLS = range(31, 37), range(23, 43)
MOUTH_ROWS, MOUTH_COLS = range(38, 40), range(30, 37)
FACE_CHARS = {"S": "iris_hi", "J": "iris_lo", "B": "pupil", "W": "eye_white", "F": "brow", "E": "brow_soft", "M": "ink"}
BODY_ROLES = frozenset({"skin", "dress_white", "dress_shade", "dress_trim", "sock", "shoe",
                        "ribbon_light", "ribbon_mid", "ribbon_dark"})
ROLE_ORDER = [
    "outline", "ink", "hair_ink", "hair_light", "hair_mid", "hair_shadow", "hair_deep", "hair_deeper",
    "skin", "blush", "brow", "brow_soft", "mouth", "mouth_soft", "eye_white", "iris_hi", "iris_lo", "pupil",
    "dress_white", "dress_shade", "dress_trim", "ribbon_light", "ribbon_mid", "ribbon_dark", "sock", "shoe",
    "ear_inner", "tail_tip", "glint",
]


def role_of(ch: str, r: int, c: int):
    """Role of one donor pixel of the hima family (hi-bit-shoujo and the r7 cuts share this character set)."""
    if ch == ".":
        return None
    if ch in HAIR_CHARS:
        return HAIR_CHARS[ch]
    if ch == "O":
        return "outline"
    if ch == "G":
        return "skin"
    in_eyes = r in EYE_ROWS and c in EYE_COLS
    if ch == "M":
        return "ink" if in_eyes else "hair_ink"       # lids are ink; every other M is a strand line
    if in_eyes:
        return FACE_CHARS.get(ch, "ink")
    if r == 37 and ch == "E":
        return "blush"
    if r in (38, 39, 40) and ch in "FE":
        return "mouth" if ch == "F" else "mouth_soft"
    if r >= 41:
        return {"W": "sock" if r >= 62 else "dress_white", "P": "dress_shade", "S": "dress_trim", "B": "shoe",
                "E": "ribbon_light", "D": "ribbon_mid", "F": "ribbon_dark"}.get(ch, "ink")
    return {"S": "iris_hi", "J": "iris_lo", "B": "pupil", "W": "eye_white", "E": "blush", "F": "mouth",
            "D": "ribbon_mid", "P": "dress_shade"}.get(ch, "ink")


def role_map(frame: list, role_fn=role_of) -> list:
    g = blank()
    for r, row in enumerate(frame):
        for c, ch in enumerate(row):
            g[r][c] = role_fn(ch, r, c)
    return g


def donor_colours(sprite: dict, tier: str = "bored", idx: int = 0, role_fn=role_of) -> dict:
    """role -> hex as the donor draws it; raises if one role would need two colours."""
    colours = {}
    for r, row in enumerate(sprite["tiers"][tier][idx]):
        for c, ch in enumerate(row):
            role = role_fn(ch, r, c)
            if role is None:
                continue
            hexv = sprite["palette"][sprite["charMap"][ch]]
            if colours.setdefault(role, hexv) != hexv:
                raise ValueError(f"role {role} maps to {colours[role]} and {hexv} at ({r},{c})")
    return colours


# ---------------------------------------------------------------- packing and validation

def to_sprite(sid: str, name: str, tiers: dict, colours: dict) -> dict:
    """Role-map frames + role->hex -> sprite JSON. Roles sharing a colour share a slot; slots follow ROLE_ORDER."""
    used = {v for frames in tiers.values() for g in frames for row in g for v in row if v is not None}
    missing = sorted(used - set(colours))
    if missing:
        raise ValueError(f"{sid}: no colour for roles {missing}")
    order = sorted(used, key=lambda x: (ROLE_ORDER.index(x) if x in ROLE_ORDER else len(ROLE_ORDER), x))
    letters = "ABCDEFGHIJKLMNOP"
    palette, char_map, char_of = [], {}, {}
    for role in order:
        hexv = colours[role].upper()
        if hexv not in char_of:
            if len(palette) == 16:
                raise ValueError(f"{sid}: more than 16 colours ({order})")
            ch = letters[len(palette)]
            char_of[hexv] = ch
            char_map[ch] = len(palette)
            palette.append(hexv)
    out_tiers = {}
    for tier in TIERS:
        out_tiers[tier] = [["".join("." if v is None else char_of[colours[v].upper()] for v in row) for row in g]
                           for g in tiers[tier]]
    return {"id": sid, "displayName": name, "cols": COLS, "rows": ROWS, "palette": palette,
            "charMap": char_map, "tiers": out_tiers}


def validate(sprite: dict) -> list:
    """The donor sprite validation rules plus this project's frame counts. Empty list = valid."""
    errs = []
    for key in ("id", "displayName", "cols", "rows", "palette", "charMap", "tiers"):
        if key not in sprite:
            errs.append(f"missing key {key!r}")
    if errs:
        return errs
    cols, rows, pal, cmap = sprite["cols"], sprite["rows"], sprite["palette"], sprite["charMap"]
    if not 1 <= len(pal) <= 16:
        errs.append(f"palette has {len(pal)} colours (1..16 allowed)")
    for i, h in enumerate(pal):
        if not re.fullmatch(r"#[0-9A-Fa-f]{6}", h):
            errs.append(f"palette[{i}] = {h!r} is not #RRGGBB")
    if "." in cmap:
        errs.append("'.' is reserved for transparent; remove it from charMap")
    if sorted(cmap.values()) != list(range(len(pal))):
        errs.append(f"charMap indices {sorted(cmap.values())} must be exactly 0..{len(pal) - 1}")
    for ch in cmap:
        if len(ch) != 1:
            errs.append(f"charMap key {ch!r} must be a single character")
    for tier in TIERS:
        frames = sprite["tiers"].get(tier)
        if not frames:
            errs.append(f"tier {tier!r} has no frames")
            continue
        if len(frames) != FRAMES[tier]:
            errs.append(f"tier {tier!r} has {len(frames)} frames, expected {FRAMES[tier]}")
        for fi, frame in enumerate(frames):
            if len(frame) != rows:
                errs.append(f"{tier}[{fi}] has {len(frame)} rows, expected {rows}")
            for ri, row in enumerate(frame):
                if len(row) != cols:
                    errs.append(f"{tier}[{fi}] row {ri} has {len(row)} chars, expected {cols}")
                bad = {c for c in row if c != "." and c not in cmap}
                if bad:
                    errs.append(f"{tier}[{fi}] row {ri} has unmapped chars {sorted(bad)}")
            if all(set(r) <= {"."} for r in frame):
                errs.append(f"{tier}[{fi}] is fully transparent")
    for extra in sprite["tiers"]:
        if extra not in TIERS:
            errs.append(f"unknown tier {extra!r}")
    if not re.fullmatch(r"[a-z0-9-]+", sprite["id"]):
        errs.append(f"id {sprite['id']!r} must be kebab-case")
    return errs


def dumps(sprite: dict) -> str:
    """Deterministic file text: one row per line, stable key order, trailing newline."""
    return json.dumps(sprite, ensure_ascii=False, indent=1) + "\n"

# ---------------------------------------------------------------- body base, skull, faces (spec §4.6, §5)

def hair_outline(rm: list, r: int, c: int) -> bool:
    """True when an outline pixel belongs to the hair silhouette: it touches hair and, below the head, no body pixel."""
    nb = [rm[rr][cc] for rr, cc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)) if 0 <= rr < ROWS and 0 <= cc < COLS]
    if not any(v is not None and v.startswith("hair") for v in nb):
        return False
    if r < 41:
        return True
    return not any(v in BODY_ROLES for v in nb)


def strip_bows(rm: list) -> list:
    """hi-bit-shoujo carries a bow on each side lock (rows 41–51); replace it with the nearest hair tone in the row."""
    for r in range(41, 52):
        for c in list(range(0, 27)) + list(range(41, COLS)):
            v = rm[r][c]
            if v is None or not v.startswith("ribbon"):
                continue
            fill = None
            for d in range(1, 7):
                for cc in (c - d, c + d):
                    if 0 <= cc < COLS and rm[r][cc] is not None and rm[r][cc].startswith("hair"):
                        fill = rm[r][cc]
                        break
                if fill:
                    break
            rm[r][c] = fill or "hair_light"
    return rm


def heal_body(g: list) -> list:
    """Fill what the donor's hair covered inside the dress: None between the row's first and last body pixel (rows 41–58)."""
    body = BODY_ROLES | {"outline", "ink"}
    for r in range(41, 59):
        cols = [c for c in range(COLS) if g[r][c] in body]
        if len(cols) < 2:
            continue
        for c in range(cols[0], cols[-1] + 1):
            if g[r][c] is None:
                g[r][c] = "dress_shade"
    return g


def body_base() -> list:
    """Face and body of the hima family: hi-bit-shoujo bored[0] without hair, bows or hair outlines, healed."""
    rm = strip_bows(role_map(load_source("hi-bit-shoujo")["tiers"]["bored"][0]))
    out = blank()
    for r in range(ROWS):
        for c in range(COLS):
            v = rm[r][c]
            if v is None or v.startswith("hair"):
                continue
            if v == "outline" and hair_outline(rm, r, c):
                continue
            out[r][c] = v
    return heal_body(out)


def skull() -> list:
    """Skin under the hair (an ellipse over rows 14–40) with an outline rim, so a blown fringe never shows background."""
    g = blank()
    cx, cy, rx, ry = 33.0, 27.0, 14.5, 13.5
    for r in range(14, 41):
        for c in range(COLS):
            d = ((c - cx) / rx) ** 2 + ((r - cy) / ry) ** 2
            if d <= 1.0:
                g[r][c] = "skin"
            elif d <= 1.18:
                g[r][c] = "outline"
    return g


def hair_from(sid: str, tier: str = "bored", idx: int = 0, dy: int = 0) -> list:
    """The hair layer of a donor: hair roles, forehead skin the fringe reveals, and the hair-silhouette outlines."""
    rm = role_map(load_source(sid)["tiers"][tier][idx])
    if sid == "hi-bit-shoujo":
        rm = strip_bows(rm)
    out = blank()
    for r in range(ROWS):
        rr = r + dy
        if not 0 <= rr < ROWS:
            continue
        for c in range(COLS):
            v = rm[r][c]
            if v is None:
                continue
            if v.startswith("hair") or (v == "skin" and r < 31) or (v == "outline" and hair_outline(rm, r, c)):
                out[rr][c] = v
    return out


def face_template(tier: str, idx: int) -> dict:
    """{(r, c): role} of the eye block rows 31–36 × cols 23–42 of a hi-bit-shoujo frame, hair pixels dropped."""
    rm = role_map(load_source("hi-bit-shoujo")["tiers"][tier][idx])
    return {(r, c): rm[r][c] for r in EYE_ROWS for c in EYE_COLS
            if rm[r][c] is not None and not rm[r][c].startswith("hair")}


def mouth_template() -> dict:
    """{(r, c): role} of the cruise smile, rows 38–39 × cols 30–36 of hi-bit-shoujo cruise[0]."""
    rm = role_map(load_source("hi-bit-shoujo")["tiers"]["cruise"][0])
    return {(r, c): rm[r][c] for r in MOUTH_ROWS for c in MOUTH_COLS if rm[r][c] is not None}


FACES = {"open": face_template("bored", 0), "blink": face_template("bored", 1)}
MOUTH = mouth_template()


def apply_face(g: list, template: dict, dy: int = 0) -> list:
    for (r, c), v in template.items():
        g[r + dy][c] = v
    return g


def face_for(pose: str, t: int) -> str:
    return "blink" if pose == "cruise" and t == 3 else "open"


def face_errors(sid: str, tiers: dict) -> list:
    """Spec §5 / §7 check: the smile in every frame and the eyes open or blinking (template pixels only), read at the
    frame's nod and hop offsets."""
    errs = []
    for tier, frames in tiers.items():
        for t, g in enumerate(frames):
            dy = NOD.get(tier, [0])[t % len(NOD.get(tier, [0]))] - HOP.get(tier, [0])[t % len(HOP.get(tier, [0]))]
            if any(g[r + dy][c] != v for (r, c), v in MOUTH.items()):
                errs.append(f"{sid}/{tier}[{t}]: mouth is not the smile")
            if not any(all(g[r + dy][c] == v for (r, c), v in FACES[name].items()) for name in FACES):
                errs.append(f"{sid}/{tier}[{t}]: eyes are not open or blink")
    return errs


# ---------------------------------------------------------------- wind and extras (spec §6, motion revised 2026-09-08)
#
# The first model sheared every row by its own travelling wave (up to 10 px at the tips, notched, with a still copy of
# the hair behind the body). At 4 fps that read as hair sliced into strips over a ghost. The bend below keeps a lock in
# one piece: a smooth profile from the root, small amplitudes, a slight lag towards the tips, and no still copy —
# a lock lying against the body keeps its inner edge and stretches, a free lock or the far side slides whole.

AMP = {"cruise": 2, "top": 2}
LEAN = {"cruise": 1, "top": 1}
CENTRE = 33                     # the body's axis: segments ending left of it are body-side locks
LAG = 0.12                      # of a cycle, at the tip: the ends follow the roots a little late


def segments(row: list) -> list:
    """Inclusive (c0, c1) runs of non-None pixels in a row."""
    out, c = [], 0
    while c < COLS:
        if row[c] is None:
            c += 1
            continue
        e = c
        while e + 1 < COLS and row[e + 1] is not None:
            e += 1
        out.append((c, e))
        c = e + 1
    return out


def bend(layer: list, amp: float, lean: float, t: int, n: int, root: int, bottom=None, stretch: bool = True) -> list:
    """Bend a hanging part to the left (the wind comes from the viewer's right).

    Row `r` moves by `dx = -round(lean·p + amp·p·w)` with `p = d²` for `d` the row's distance from `root` towards
    `bottom` (0..1) and `w = ½ + ½·sin(2π(t/n − LAG·d))`, so the root is still, the profile is smooth and the tips
    lag slightly. A segment that ends left of CENTRE is a lock against the body: when `stretch` is on it keeps its
    inner edge and is resampled wider (no gap opens beside the body, no ghost copy is needed). Every other segment —
    a free twintail (`stretch=False`), the far side, a row spanning the centre — slides whole by `dx`.
    `bottom` above `root` (hat tip, leaf) makes the top move instead."""
    b = bounds(layer)
    if b is None:
        return blank()
    bottom = b[1] if bottom is None else bottom
    out = blank()
    for r in range(ROWS):
        row = layer[r]
        segs = segments(row)
        if not segs:
            continue
        d = 0.0 if bottom == root else max(0.0, min(1.0, (r - root) / (bottom - root)))
        p = d * d
        w = 0.5 + 0.5 * math.sin(2 * math.pi * (t / n - LAG * d))
        dx = -int(round(lean * p + amp * p * w))
        for c0, c1 in segs:
            if dx != 0 and stretch and c1 < CENTRE:
                length, wider = c1 - c0 + 1, c1 - c0 + 1 - dx
                for x in range(c0 + dx, c1 + 1):
                    if 0 <= x < COLS:
                        src = c0 + int((x - (c0 + dx)) * length / wider)
                        out[r][x] = row[min(c1, max(c0, src))]
            else:
                for c in range(c0, c1 + 1):
                    if 0 <= c + dx < COLS:
                        out[r][c + dx] = row[c]
    return out


def wag(layer: list, amp: float, t: int, n: int) -> list:
    """Vertical sway of a tail or a wing: pixels move more the further they are from the root column, which is the
    layer's end nearest the body's axis (a tail on the right roots at its left end, a wing on the left at its right end)."""
    b = bounds(layer)
    if b is None:
        return blank()
    c0, c1 = b[2], b[3]
    root = c0 if abs(c0 - CENTRE) <= abs(c1 - CENTRE) else c1
    out = blank()
    for r in range(ROWS):
        for c in range(COLS):
            v = layer[r][c]
            if v is None:
                continue
            dy = int(round(amp * abs(c - root) / max(1, c1 - c0) * math.sin(2 * math.pi * t / n)))
            if 0 <= r + dy < ROWS:
                out[r + dy][c] = v
    return out


def heal_holes(g: list, max_size: int = 4) -> list:
    """Fill enclosed transparent pockets of up to `max_size` pixels with their commonest non-outline neighbour role.

    The 1-px nod and the bend can pinch a pixel or two between a lock and the dress; those pockets read as holes at
    280 px. Pockets that touch a glint (a sparkle) and larger see-through windows are left alone."""
    seen = [[False] * COLS for _ in range(ROWS)]
    stack = [(r, c) for r in range(ROWS) for c in (0, COLS - 1) if g[r][c] is None]
    stack += [(r, c) for c in range(COLS) for r in (0, ROWS - 1) if g[r][c] is None]
    while stack:
        r, c = stack.pop()
        if seen[r][c]:
            continue
        seen[r][c] = True
        for rr, cc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
            if 0 <= rr < ROWS and 0 <= cc < COLS and not seen[rr][cc] and g[rr][cc] is None:
                stack.append((rr, cc))
    for r in range(ROWS):
        for c in range(COLS):
            if g[r][c] is not None or seen[r][c]:
                continue
            region, stack = [], [(r, c)]
            while stack:
                rr, cc = stack.pop()
                if seen[rr][cc]:
                    continue
                seen[rr][cc] = True
                region.append((rr, cc))
                for r2, c2 in ((rr - 1, cc), (rr + 1, cc), (rr, cc - 1), (rr, cc + 1)):
                    if 0 <= r2 < ROWS and 0 <= c2 < COLS and g[r2][c2] is None and not seen[r2][c2]:
                        stack.append((r2, c2))
            if len(region) > max_size:
                continue
            neighbours = []
            for rr, cc in region:
                for r2, c2 in ((rr - 1, cc), (rr + 1, cc), (rr, cc - 1), (rr, cc + 1)):
                    if 0 <= r2 < ROWS and 0 <= c2 < COLS and g[r2][c2] is not None:
                        neighbours.append(g[r2][c2])
            if "glint" in neighbours:
                continue
            soft = [v for v in neighbours if v != "outline"] or neighbours
            fill = max(sorted(set(soft)), key=soft.count)      # sorted: a tie must not depend on the hash seed
            for rr, cc in region:
                g[rr][cc] = fill
    return g


SPARKS = [(6, 10), (12, 58), (30, 62), (50, 6), (44, 60), (18, 4)]


def sparkles(g: list, t: int) -> list:
    """Six fixed points cycling plus → dot → off (top pose)."""
    for i, (r, c) in enumerate(SPARKS):
        phase = (i + t) % 3
        pts = [(r, c), (r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)] if phase == 0 else [(r, c)] if phase == 1 else []
        for rr, cc in pts:
            if 0 <= rr < ROWS and 0 <= cc < COLS and g[rr][cc] is None:
                g[rr][cc] = "glint"
    return g


# ---------------------------------------------------------------- recipes and frame building

HEAD_BOTTOM = 40                # body rows 0..40 are the head; they nod with the hair, the torso below stays


@dataclass
class Part:
    grid: list
    motion: str = "bend"           # "bend" | "wag" | "rigid"
    root: int = 12                 # bend: root row (no motion); rows towards `bottom` move more
    bottom: int | None = None      # bend: row that gets the full amplitude (default: the layer's last row)
    scale: float = 1.0             # amplitude and lean multiplier (hat tip, cape, leaf: 0.5)
    cap: int | None = None         # max amplitude and lean in px after scaling (leaf: 2)
    stretch: bool = True           # bend: a lock ending left of CENTRE keeps its inner edge (False for free twintails)
    nod: bool | None = None        # move with the head's 1-px nod; default: front parts yes, back parts no


@dataclass
class Recipe:
    id: str
    name: str
    colours: dict
    body: list                     # rigid pixels, drawn after `back`
    front: list = field(default_factory=list)   # Parts drawn over the body, in order
    back: list = field(default_factory=list)    # Parts drawn behind the body (tail, props)
    face: bool = True              # apply the face set of spec §5


def animate(part: Part, pose: str, t: int) -> list:
    if part.motion not in ("bend", "wag", "rigid"):
        raise ValueError(f"unknown motion {part.motion!r}")
    if part.motion == "rigid":
        return copy(part.grid)                     # never hand out the recipe's own grid
    n = FRAMES[pose]
    amp, lean = AMP[pose] * part.scale, LEAN[pose] * part.scale
    if part.cap is not None:
        amp, lean = min(amp, part.cap), min(lean, part.cap)
    if part.motion == "wag":
        return wag(part.grid, amp / 2, t, n)
    return bend(part.grid, amp, lean, t, n, part.root, part.bottom, part.stretch)


def split_head(body: list):
    """(head rows 0..HEAD_BOTTOM, torso below) of a body layer."""
    head, torso = blank(), blank()
    for r in range(ROWS):
        (head if r <= HEAD_BOTTOM else torso)[r] = body[r][:]
    return head, torso


def hop(g: list, rows: int) -> list:
    """Lift the whole frame by `rows` (the top alert); a recipe that draws in the rows that fall off is a bug."""
    if rows == 0:
        return g
    lost = [(r, c) for r in range(rows) for c in range(COLS) if g[r][c] is not None]
    if lost:
        raise ValueError(f"hop of {rows} px would clip {len(lost)} pixel(s) at rows 0..{rows - 1} (first {lost[0]})")
    return g[rows:] + [[None] * COLS for _ in range(rows)]


def build_frame(recipe: Recipe, pose: str, t: int) -> list:
    """One frame: back parts, torso, then the head with its hair and accessories nodded by NOD[pose][t] pixels,
    the whole lifted by HOP[pose][t], then the pose extras (sparkles on top)."""
    dy = NOD[pose][t]
    g = blank()
    for part in recipe.back:
        paste(g, animate(part, pose, t), dy=dy if part.nod else 0)
    head, torso = split_head(recipe.body)
    paste(g, torso)
    paste(g, head, dy=dy)
    for part in recipe.front:
        paste(g, animate(part, pose, t), dy=0 if part.nod is False else dy)
    if recipe.face:
        apply_face(g, FACES[face_for(pose, t)], dy)
        apply_face(g, MOUTH, dy)
    heal_holes(g)
    g = hop(g, HOP[pose][t])
    if pose == "top":
        sparkles(g, t)
    return g


def build_tiers(recipe: Recipe) -> dict:
    return {pose: [build_frame(recipe, pose, t) for t in range(FRAMES[pose])] for pose in TIERS}


def build_sprite(recipe: Recipe) -> dict:
    colours = dict(recipe.colours)
    colours.setdefault("glint", colours.get("eye_white", "#FFFFFF"))
    tiers = build_tiers(recipe)
    errs = face_errors(recipe.id, tiers) if recipe.face else []
    sprite = to_sprite(recipe.id, recipe.name, tiers, colours)
    errs += validate(sprite)
    if errs:
        raise ValueError("\n".join(errs))
    return sprite
