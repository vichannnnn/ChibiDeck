"""Stella — a star-gazer in teal: Rowena Rig's long cut in silver made curly (scalloped outer edges, hooked tips, curl
strand lines), a white beret worn tilted to the viewer's left with a teal band, a gold star pin on its left and a big
teal bow on its right crowned by a white flower, one ribbon tail hanging down the right lock, small white wings behind
her shoulders that flap, a teal dress with a white scalloped capelet, a blue chest bow and star glints on the skirt.
Theme starfall (tap order 7). Reference: the user's ref-05. Round three (2026-09-08): "hair curlier", "where is the
ribbon + white flower hairpin?", "dress more details"."""
from __future__ import annotations

from parts import ACC, base_colours, body_with_skull
from rig import COLS, ROWS, Part, Recipe, blank, hair_from, mirror, paste_grid

# legend: parts.ACC plus T = the teal dress colour (dress_white), H = pale blue (iris_hi)
LEGEND = dict(ACC, T="dress_white", H="iris_hi")

BERET = [                   # cols 19–45, rows 3–12: a soft white dome, shaded on the right, teal band along the edge
    ".......ooooooooo...........",
    "....oooWWWWWWWWWooo........",
    "..ooWWWWWWWWWWWWWWWoo......",
    ".oWWWWWWWWWWWWWWWWWWWso....",
    ".oWWWWWWWWWWWWWWWWWWsssso..",
    "oWWWWWWWWWWWWWWWWWWssssso..",
    "oWWWWWWWWWWWWWWWWWsssssssso",
    "oTTTTTTTTTTTTTTTTTTTTTTTTTo",
    ".oTTTTTTTTTTTTTTTTTTTTTTTo.",
    "..ooooooooooooooooooooooo..",
]
STAR = [                    # gold star pin on the beret's left, outlined
    "...o...",
    "..oAo..",
    ".oAAAo.",
    "oAAAAAo",
    ".oAAAo.",
    "..oAo..",
    "...o...",
]
BIG_BOW = [                 # cols 40–56, rows 3–11: two wide teal loops either side of a knot, shaded on the right
    "...oooo....oooo..",
    "..oTTTTo..oTTTTo.",
    ".oTHTTTToooTTTTPo",
    ".oTTTTTToToTTTPPo",
    "oTTTTTTToToTTTPPo",
    "oTTTTTTTToTTTPPPo",
    ".oTTTTTToooTTPPo.",
    "..oTTTTo.oPPPPo..",
    "...oooo...oooo...",
]
FLOWER = [                  # 7×7 white flower with a pale-blue heart and a gold centre, over the bow's knot
    "..ooo..",
    ".oWWWo.",
    "oWWHWWo",
    "oWHAHWo",
    "oWWHWWo",
    ".oWWWo.",
    "..ooo..",
]
TAIL = [                    # cols 44–48, rows 11–28: one ribbon tail hugging the right lock, wavy and tapering
    "oTTTo",
    "oTTPo",
    "oTTPo",
    ".oTPo",
    ".oTPo",
    ".oTPo",
    "oTTPo",
    "oTTPo",
    "oTPo.",
    "oTPo.",
    ".oTPo",
    ".oTPo",
    "oTTPo",
    "oTPo.",
    "oTPo.",
    ".oPo.",
    ".oPo.",
    "..o..",
]
CURLS = [                   # left lock's outer edge, cols 11–16, rows 41–59: scalloped bumps and a hooked tip
    ".....l",
    "....ol",
    "...oll",
    "..olml",
    "..olml",
    "...oll",
    "....ol",
    "...oll",
    "..olml",
    ".olmml",
    ".olmml",
    "..olml",
    "...oll",
    "..olsl",
    ".olssl",
    ".olsdl",
    "..osdo",
    "...ood",
    "....oo",
]
CHEST_BOW = [               # blue bow under the collar, cols 30–36, rows 43–47 ('.' keeps the capelet white)
    "oo.o.oo",
    "oMoMoMo",
    ".oMMMo.",
    "oMoMoMo",
    "oo.o.oo",
]
GLINT = [
    ".W.",
    "WWW",
    ".W.",
]
WING = [                    # left wing, cols 4–28, rows 40–52; cols 15–28 sit behind the lock and the dress and only bridge
    ".....oo..................",
    "....oWWo.................",
    "...oWWWWo................",
    "..oWWsWWWoo..............",
    ".oWWsWWWWWWoooooooooooooo",
    "oWWsWWWWWWWWWWWWWWWWWWWWW",
    "oWsWWWsWWWWWWWWWWWWWWWWWW",
    "oWWsWWWsWWWWWWWWWWWWWWWWW",
    ".oWWsWWWsWWWWWWWWWWWWWWWW",
    ".oWWWsWWWsWWWWWWWWWWWWWWW",
    "..oWWWsWWWsWWWWWWWWWWWWWW",
    "...oWWWWsWWWWWWWWWWWWWWWW",
    "....ooooooooooooooooooooo",
]

SHINE = [(14, 24), (14, 25), (14, 26), (15, 23), (15, 24), (16, 22),           # gleam on the upper left of the crown
         (15, 38), (15, 39), (16, 40)]
CURL_LINES = [(24, 18, 30, 0), (20, 42, 56, 2), (23, 44, 56, 5), (38, 18, 30, 3), (46, 42, 56, 1), (48, 46, 56, 4),
              (17, 44, 54, 3)]                                                  # (col, r0, r1, phase): tight waves


def curl(col: int, r0: int, r1: int, phase: int = 0) -> list:
    """Cells of a tight wave (period 4, ±1) — a curl line rather than a straight strand."""
    cells = []
    for i, r in enumerate(range(r0, r1 + 1)):
        k = (i + phase) % 4
        cells.append((r, col + (1 if k == 1 else -1 if k == 3 else 0)))
    return cells


def detail(hair: list) -> list:
    """Curl bumps on both locks, gleam strokes in white on the crown, and curl lines through the planes and locks."""
    paste_grid(hair, CURLS, LEGEND, 11, 41)
    paste_grid(hair, mirror(CURLS), LEGEND, 50, 41)
    for r, c in SHINE:
        if hair[r][c] is not None and hair[r][c].startswith("hair"):
            hair[r][c] = "eye_white"
    for col, r0, r1, phase in CURL_LINES:
        for r, c in curl(col, r0, r1, phase):
            if 0 <= r < ROWS and 0 <= c < COLS and hair[r][c] in ("hair_light", "hair_mid"):
                hair[r][c] = "hair_shadow"
    return hair


def capelet(body: list) -> list:
    """A white capelet over the shoulders (rows 41–45) with a scalloped edge on row 46, a blue chest bow, star glints
    on the skirt and white lace dots on the hem band."""
    cloth = {"dress_white", "dress_shade", "dress_trim", "ribbon_light", "ribbon_mid", "ribbon_dark"}
    for r in range(41, 46):
        for c in range(COLS):
            if body[r][c] in cloth:
                body[r][c] = "dress_trim"
    for c in range(COLS):
        if body[46][c] in cloth and c % 3 != 1:
            body[46][c] = "dress_trim"
    paste_grid(body, CHEST_BOW, LEGEND, 30, 43)
    paste_grid(paste_grid(body, GLINT, LEGEND, 27, 52), GLINT, LEGEND, 37, 54)
    for c in range(24, 45, 3):
        if body[57][c] == "dress_trim":
            body[57][c] = "dress_shade"
    return body


def recipe() -> Recipe:
    hair = detail(hair_from("rowena-rig"))
    beret = paste_grid(blank(), BERET, LEGEND, 19, 3)
    paste_grid(beret, STAR, LEGEND, 22, 5)
    paste_grid(beret, BIG_BOW, LEGEND, 40, 3)
    paste_grid(beret, FLOWER, LEGEND, 45, 4)
    tail = paste_grid(blank(), TAIL, LEGEND, 44, 11)
    left_wing = paste_grid(blank(), WING, LEGEND, 4, 40)
    right_wing = paste_grid(blank(), mirror(WING), LEGEND, 39, 40)
    colours = base_colours(
        hair_light="#F7F9FF", eye_white="#F7F9FF", sock="#F7F9FF", dress_trim="#F7F9FF",
        hair_mid="#DCE3F0", hair_shadow="#B5C2D8", hair_deep="#8797B8", hair_deeper="#8797B8",
        dress_white="#4C9DAA", dress_shade="#3A7F8B",
        iris_hi="#BFE6F0", iris_lo="#4F9DB8", pupil="#14324A", shoe="#14324A", ribbon_dark="#14324A",
        blush="#F2B0BC", brow_soft="#F2B0BC", mouth_soft="#F2B0BC", mouth="#8C5A6A", brow="#8C5A6A",
        ribbon_mid="#3F6FD8", ribbon_light="#BFE6F0", accent_a="#F2C55C",
        ink="#0F1E28", hair_ink="#0F1E28", outline="#040A10")
    return Recipe("stella", "Stella", colours, capelet(body_with_skull()),
                  front=[Part(hair, root=12), Part(tail, root=12, scale=0.5, cap=2), Part(beret, "rigid")],
                  back=[Part(left_wing, "wag"), Part(right_wing, "wag")])
