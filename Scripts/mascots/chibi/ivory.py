"""Ivory — a porcelain doll: hi-bit-shoujo's flared long cut in silver-white with wave strand lines, a white top hat
perched a little to the left (shaded crown, black band, a royal-blue two-loop bow with a gem knot on the right of the
brim with a white feather rising behind it, its tails hanging down the right side of the hair and swinging), a blue
chest bow with a gem, and a white dress with blue bands, lace dots, blue sash tails and a fold in the skirt. Theme
porcelain (tap order 3). Reference: the user's ref-04 (silver hair, black-banded hat, blue bow and feather, blue chest
bow). Round three 2026-09-08: hat two rows lower for the hop, hair silver, band black, bow and feather to the right,
chest bow and sash added."""
from __future__ import annotations

from parts import ACC, base_colours, body_with_skull
from rig import COLS, ROWS, Part, Recipe, blank, hair_from, paste_grid

LEGEND = dict(ACC, J="iris_lo")
# legend — o outline · W white · P dress_shade · k ink (band) · M bow (ribbon_mid) · E bow light (ribbon_light) · F bow dark
# (ribbon_dark) · J gem (iris_lo) · s hair_shadow

CROWN = [                   # 22 wide, leaning left: the top two rows sit one column further left
    "oooooooooooooooooooooo.",
    "oWWWWWWWWWWWWWWWWWWPPo.",
    "oWWWWWWWWWWWWWWWWWWPPo.",
    ".oWWWWWWWWWWWWWWWWWWPPo",
    ".oWWWWWWWWWWWWWWWWWWPPo",
    ".oWWWWWWWWWWWWWWWWWWPPo",
]
BAND = [                    # two rows of black ribbon (the reference's), a shade line at the bottom
    "okkkkkkkkkkkkkkkkkkkkkko",
    "okkkkkkkkkkkkkkkkkkkkkko",
]
BRIM = [                    # 30 wide, two rows deep, shaded towards the right
    "oooooooooooooooooooooooooooooo",
    "oPWWWWWWWWWWWWWWWWWWWWWWPPPPPo",
    "oPPWWWWWWWWWWWWWWWWWWWWPPPPPPo",
    ".oooooooooooooooooooooooooooo.",
]
BOW = [                     # 11×9 royal-blue two-loop bow with a gem knot, on the brim's right end
    ".ooo...ooo.",
    "oEWMo.oMEWo",
    "oEMMMoMMMEo",
    "oMMMoJoMMFo",
    ".oMMoJoMFo.",
    "oMMMoooMMFo",
    "oMMFMoMFFFo",
    "oFFFo.oFFFo",
    ".ooo...ooo.",
]
FEATHER = [                 # a white feather rising up and right from behind the bow, a shade line down its spine
    ".......oo",
    "......oWo",
    ".....oWWo",
    "....oWPWo",
    "...oWWPWo",
    "..oWPWWo.",
    ".oWWPWo..",
    "oWPWWo...",
    "oWWWo....",
    "oooo.....",
]
CHEST_BOW = [               # 10×7 blue bow at the collar with a gem knot (held by the torso: no nod)
    ".oo....oo.",
    "oMEo..oEMo",
    "oMMMooMMMo",
    ".oMMJJMMo.",
    "oMMMooMMMo",
    "oMFo..oFMo",
    ".oo....oo.",
]
BOW_TAILS = [               # two strips hanging from the bow, side by side, lighter edge
    "oMMoMMo",
    "oMMoMMo",
    "oEMoMFo",
    "oMMoMMo",
    "oEMoMFo",
    "oMMoMMo",
    ".oMoMo.",
    ".oMoMo.",
    "..o.o..",
]


def top_hat() -> list:
    """Crown rows 2–7 at cols 24–46, band rows 8–9 at cols 23–46, brim rows 10–13 at cols 19–48, feather rows 2–11 at
    cols 45–53 behind the bow at rows 7–15, cols 41–51. Rows 0–1 stay empty for the top pose's hop."""
    g = blank()
    paste_grid(g, FEATHER, LEGEND, 45, 2)
    paste_grid(g, CROWN, LEGEND, 24, 2)
    paste_grid(g, BAND, LEGEND, 23, 8)
    paste_grid(g, BRIM, LEGEND, 19, 10)
    paste_grid(g, BOW, LEGEND, 41, 7)
    return g


def is_hair(v) -> bool:
    return v is not None and v.startswith("hair") and v != "hair_ink"


def stroke(layer: list, cells: list, role: str) -> list:
    """Paint `role` on the given cells, only where the layer already has hair — never over air or outline."""
    for r, c in cells:
        if 0 <= r < ROWS and 0 <= c < COLS and is_hair(layer[r][c]):
            layer[r][c] = role
    return layer


def wave(col: int, r0: int, r1: int, swing: int = 1, period: int = 6, phase: int = 0) -> list:
    """Cells of a gently waving vertical strand: the column drifts ±`swing` over `period` rows."""
    cells = []
    for i, r in enumerate(range(r0, r1 + 1)):
        k = (i + phase) % period
        dx = 0 if k in (0, 1, period // 2, period // 2 + 1) else (swing if k < period // 2 else -swing)
        cells.append((r, col + dx))
    return cells


def detail_hair(hair: list) -> list:
    """A shadow row under the brim, wave lines along the locks, and a few lighter strands between them."""
    for r in (14, 15):
        for c in range(21, 47):
            if is_hair(hair[r][c]) and hair[r][c] != "hair_deep":
                hair[r][c] = "hair_shadow"
    for col, r0, r1, phase in ((20, 43, 53, 0), (23, 44, 55, 3), (18, 47, 54, 1),
                               (46, 44, 53, 2), (49, 45, 55, 5), (51, 47, 53, 0),
                               (22, 24, 30, 0), (44, 23, 30, 3)):
        stroke(hair, wave(col, r0, r1, phase=phase), "hair_shadow")
    for col, r0, r1 in ((17, 45, 50), (52, 46, 51), (34, 14, 17)):
        stroke(hair, [(r, col) for r in range(r0, r1 + 1)], "hair_light")
    return hair


def dress(body: list) -> list:
    """Lace dots on the blue bands at rows 50 and 57, two blue sash tails from the waist, and a fold in the skirt."""
    for r in (50, 57):
        for c in range(24, 45, 3):
            if body[r][c] == "dress_trim":
                body[r][c] = "dress_white"
    for r in range(51, 57):
        for c, role in ((27, "ribbon_mid"), (28, "ribbon_light"), (29, "ribbon_mid")):
            if body[r][c] == "dress_white" and not (r == 56 and c == 28):
                body[r][c] = role
    for r in range(52, 57):
        if body[r][36] == "dress_white":
            body[r][36] = "dress_shade"
    return body


def recipe() -> Recipe:
    hair = detail_hair(hair_from("hi-bit-shoujo"))
    tails = paste_grid(blank(), BOW_TAILS, LEGEND, 44, 16)
    chest = paste_grid(blank(), CHEST_BOW, LEGEND, 29, 41)
    colours = base_colours(
        hair_light="#FFFFFF", hair_mid="#EDEAF5", hair_shadow="#C8C2DB", hair_deep="#9C95B8", hair_deeper="#6C6690",
        eye_white="#FFFFFF", dress_white="#FFFFFF", sock="#FFFFFF", dress_shade="#E3E0EE",
        dress_trim="#3F6FD8", ribbon_mid="#3F6FD8", ribbon_light="#86ACF5",
        iris_hi="#BFCBFF", iris_lo="#6E7CDD", pupil="#2A2D5C", shoe="#2A2D5C", ribbon_dark="#2A2D5C",
        blush="#F3B0B8", brow_soft="#F3B0B8", mouth_soft="#F3B0B8",
        mouth="#9A5A6A", brow="#9A5A6A",
        ink="#10122A", hair_ink="#10122A", outline="#05060F")
    return Recipe("ivory", "Ivory", colours, dress(body_with_skull()),
                  front=[Part(hair, root=12),
                         Part(tails, root=16, scale=0.5, cap=2),
                         Part(top_hat(), "rigid"),
                         Part(chest, "rigid", nod=False)])
