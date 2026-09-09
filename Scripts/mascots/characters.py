#!/usr/bin/env python3
"""The panel mascots as rig recipes: Mage (spec 2026-09-08 §4.5) here, the chibi roster under chibi/.
Ember, Marina and Clover (§4.2–4.4) were retired in round three of the roster (roster spec §6)."""
from __future__ import annotations

from rig import COLS, ROWS, EYE_COLS, EYE_ROWS, FACE_CHARS, Part, Recipe, blank, load_source, role_map, skull

# ---------------------------------------------------------------- Mage (spec §4.5): own pixels, classed by motion

MAGE_HAIR = {"K": "hair_shadow", "N": "hair_mid", "A": "hair_light", "L": "hair_deep"}


def mage_role_of(ch: str, r: int, c: int):
    """Face roles inside the eye and mouth blocks, hair roles for K N A L, and `m:<char>` for everything else."""
    if ch == ".":
        return None
    in_eyes = r in EYE_ROWS and c in EYE_COLS
    if in_eyes and ch in FACE_CHARS:
        return FACE_CHARS[ch]
    if in_eyes and ch == "G":
        return "skin"
    if ch in MAGE_HAIR:
        return MAGE_HAIR[ch]
    if 24 <= r <= 40 and 20 <= c <= 46 and ch == "G":
        return "skin"
    if r == 37 and 23 <= c <= 42 and ch == "E":
        return "blush"
    if r in (38, 39) and 30 <= c <= 36 and ch in "FE":
        return "mouth" if ch == "F" else "mouth_soft"
    return "m:" + ch


def mage_hair_outline(rm: list, r: int, c: int) -> bool:
    """An `m:O` pixel that touches hair and nothing else but hair, outline or background moves with the hair."""
    nb = [rm[rr][cc] for rr, cc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)) if 0 <= rr < ROWS and 0 <= cc < COLS]
    if not any(v is not None and v.startswith("hair") for v in nb):
        return False
    return all(v is None or v.startswith("hair") or v == "m:O" for v in nb)


def mage() -> Recipe:
    src = load_source("mage")
    rm = role_map(src["tiers"]["bored"][0], mage_role_of)
    hair, tip, cape, body = blank(), blank(), blank(), skull()
    for r in range(ROWS):
        for c in range(COLS):
            v = rm[r][c]
            if v is None:
                continue
            ribbon_tail = v in ("m:B", "m:J") and 43 <= c <= 48 and 16 <= r <= 31
            if v.startswith("hair") or ribbon_tail or (v == "m:O" and mage_hair_outline(rm, r, c)):
                hair[r][c] = v
            elif r <= 12:
                tip[r][c] = v
            elif 41 <= r <= 58 and v in ("m:P", "m:M", "m:C", "m:O") and not 27 <= c <= 40:
                cape[r][c] = v
            else:
                body[r][c] = v
    inv = {v: k for k, v in src["charMap"].items()}
    colours = {"m:" + inv[i]: h for i, h in enumerate(src["palette"])}
    by_char = {inv[i]: h for i, h in enumerate(src["palette"])}
    colours.update({
        "hair_light": by_char["A"], "hair_mid": by_char["N"], "hair_shadow": by_char["K"], "hair_deep": by_char["L"],
        "iris_hi": by_char["S"], "iris_lo": by_char["J"], "pupil": by_char["B"], "eye_white": by_char["W"],
        "ink": by_char["M"], "hair_ink": by_char["M"], "skin": by_char["G"], "blush": by_char["E"],
        "brow": by_char["F"], "brow_soft": by_char["E"], "mouth": by_char["F"], "mouth_soft": by_char["E"],
        "outline": by_char["O"], "glint": by_char["W"],
    })
    return Recipe("mage", "Mage", colours, body,
                  front=[Part(cape, root=41, scale=0.5),
                         Part(hair, root=16),
                         Part(tip, root=12, bottom=3, scale=0.5)])


RECIPES = {"mage": mage}   # tap order (spec §1): Mage first, then the chibi roster

# The chibi roster (2026-09-08) continues the tap order after Mage; one module per character under chibi/.
from chibi import RECIPES as CHIBI_RECIPES   # noqa: E402
RECIPES.update(CHIBI_RECIPES)
