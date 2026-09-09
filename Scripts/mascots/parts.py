#!/usr/bin/env python3
"""Building blocks shared by every mascot recipe (spec 2026-09-08 §4; chibi roster 2026-09-08).

The hima-family colour defaults, the body with its skull, the accessory legends, and the layer helpers that more
than one character needs (erasing a donor's ahoge, recolouring the tips of the hair, counting enclosed holes)."""
from __future__ import annotations

from rig import COLS, ROWS, blank, body_base, paste, skull


# ---------------------------------------------------------------- colours and body

def base_colours(**over) -> dict:
    """The hima-family defaults (skin, outline, ink, face lines); every recipe overrides the rest."""
    c = {
        "outline": "#040316", "ink": "#1E1A3C", "hair_ink": "#1E1A3C", "skin": "#FADBCF", "eye_white": "#FFFFFF",
        "blush": "#E58BB0", "brow": "#924C62", "brow_soft": "#E58BB0", "mouth": "#924C62", "mouth_soft": "#E58BB0",
        "dress_white": "#FBF9FF", "dress_shade": "#E7E1F6", "dress_trim": "#CBBCFF", "sock": "#FBF9FF", "shoe": "#3D3273",
        "ribbon_light": "#E58BB0", "ribbon_mid": "#C86A92", "ribbon_dark": "#924C62",
    }
    c.update(over)
    return c


def body_with_skull() -> list:
    return paste(skull(), body_base())


# ---------------------------------------------------------------- accessory legends
# o outline · l hair_light · m hair_mid · s hair_shadow · d hair_deep · D hair_deeper · i ear_inner · w tail_tip
# W eye_white (the character's white) · P dress_shade · S dress_trim · E ribbon_light · M ribbon_mid · F ribbon_dark
# g skin · e blush · k ink · A accent_a · B accent_b (two free roles a recipe may colour as it likes)

ACC = {"o": "outline", "l": "hair_light", "m": "hair_mid", "s": "hair_shadow", "d": "hair_deep", "D": "hair_deeper",
       "i": "ear_inner", "w": "tail_tip", "W": "eye_white", "P": "dress_shade", "S": "dress_trim",
       "E": "ribbon_light", "M": "ribbon_mid", "F": "ribbon_dark", "g": "skin", "e": "blush", "k": "ink",
       "A": "accent_a", "B": "accent_b"}


# ---------------------------------------------------------------- layer helpers

def erase_rows(layer: list, r0: int, r1: int) -> list:
    """Clear rows r0..r1 inclusive (a donor's ahoge under a hat)."""
    for r in range(max(0, r0), min(ROWS, r1 + 1)):
        layer[r] = [None] * COLS
    return layer


def erase_box(layer: list, r0: int, r1: int, c0: int, c1: int) -> list:
    """Clear the box rows r0..r1 × cols c0..c1 inclusive."""
    for r in range(max(0, r0), min(ROWS, r1 + 1)):
        for c in range(max(0, c0), min(COLS, c1 + 1)):
            layer[r][c] = None
    return layer


def remap_below(layer: list, row: int, mapping: dict, fade: int = 0) -> list:
    """Rename roles from `row` down — gradient hair tips. The `fade` rows above `row` take the new role on a
    checkerboard so the boundary dithers instead of cutting. Roles not in `mapping` are left alone."""
    for r in range(max(0, row - fade), ROWS):
        for c in range(COLS):
            v = layer[r][c]
            if v in mapping and (r >= row or (r + c) % 2 == 0):
                layer[r][c] = mapping[v]
    return layer


def holes(frame: list) -> int:
    """Enclosed transparent pixels: None cells a 4-connected flood from the border cannot reach (spec §9 R3)."""
    seen = [[False] * COLS for _ in range(ROWS)]
    stack = [(r, c) for r in range(ROWS) for c in (0, COLS - 1) if frame[r][c] is None]
    stack += [(r, c) for c in range(COLS) for r in (0, ROWS - 1) if frame[r][c] is None]
    while stack:
        r, c = stack.pop()
        if seen[r][c]:
            continue
        seen[r][c] = True
        for rr, cc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
            if 0 <= rr < ROWS and 0 <= cc < COLS and not seen[rr][cc] and frame[rr][cc] is None:
                stack.append((rr, cc))
    return sum(1 for r in range(ROWS) for c in range(COLS) if frame[r][c] is None and not seen[r][c])
