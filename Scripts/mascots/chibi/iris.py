"""Iris — long fluffy silver-lavender hair, a thin gold chain circlet with a drop gem on the fringe, a blue blossom at
each temple and a bud on the right lock, a white dress with periwinkle and gold trims over a pale-blue layered skirt
that spreads behind her; theme moonlit-iris (tap order 6). Reference: the silver-haired girl with the circlet and blue
flowers (ref-09). Round three (2026-09-08): "hair more fluffy", "the fluffy dress behind", "dress more detailed",
"colour palette consistent".

Hair is Rowena Rig's long cut made fluffy: a soft volume bump on each side of the head, the locks flare into rounded
curls with hooked tips, a rounder crown, and wavy strand lines through the planes. The back skirt is a `back`
bend part (root 41, half amplitude, capped at 2 px) in the dress's own pale blue with a gold cord above a scalloped
white hem, so it sways a little behind the body. Everything sits on one palette: silver-lavender hair, white, two blues,
one gold; hair_deeper shares hair_deep to pay for the skirt's blue."""
from rig import COLS, ROWS, Part, Recipe, blank, hair_from, mirror, paste_grid
from parts import ACC, base_colours, body_with_skull

LEGEND = dict(ACC, J="iris_lo", H="iris_hi")
# legend — o outline · l m s d hair light/mid/shadow/deep · W white · P dress_shade · S dress_trim (periwinkle)
#          B accent_b (skirt blue) · A accent_a (gold) · J iris_lo · H iris_hi

CHAIN = [                   # 26 wide at cols 20–45, rows 13–18: A the chain, o its shadow
    ".........AAAAAAAA.........",
    "......AAAooooooooAAA......",
    "....AAooo........oooAA....",
    "..AAoo..............ooAA..",
    "AAoo..................ooAA",
    "oo......................oo",
]
GEM = [                     # 5×4 drop gem at cols 31–35, rows 14–17
    ".oJo.",
    "oJHJo",
    "oJJJo",
    ".oJo.",
]
BEAD = ["JJ", "JJ"]         # 2×2 beads on the chain at cols 25–26 and 40–41, rows 14–15
BLOSSOM = [                 # 9×9 four-petal blossom: blue petals with pale rims, a gold diamond centre with a dark dot
    "...ooo...",
    "..oHMHo..",
    ".ooMMMoo.",
    "oHMMAMMHo",
    "oMMAoAMMo",
    "oHMMAMMHo",
    ".ooMMMoo.",
    "..oHMHo..",
    "...ooo...",
]
BUD = [                     # 5×4 bud painted into the right lock at cols 45–49, rows 36–39
    ".oMo.",
    "oMHMo",
    "oMAMo",
    ".oMo.",
]
CROWN = [                   # a rounder, one-row-taller crown, cols 27–38, rows 9–10 (row 10 replaces the outline)
    "..oooooooo..",
    "oollllmmmmoo",
]
PUFF = [                    # left side volume, cols 11–16, rows 25–38; col 16 replaces the head outline
    "....o.",
    "...oll",
    "..olml",
    ".olmml",
    ".olmml",
    ".olmml",
    ".olmml",
    ".olmsl",
    ".olmsl",
    "..omsl",
    "..ossl",
    "...osl",
    "....ol",
    ".....o",
]
FLARE = [                   # left lock end, cols 9–16, rows 46–59: a rounded curl that hooks in under the lock
    "......ol",
    ".....oll",
    "....olll",
    "...ollml",
    "..ollmml",
    "..olmmml",
    ".olmmmml",
    ".olmmsml",
    ".olmsssl",
    "..olsssl",
    "..oosdsl",
    "...oodd.",
    "....oodo",
    ".....ooo",
]
SHINE = [(17, 33), (17, 34), (17, 35), (17, 36), (19, 36), (19, 37), (20, 21), (21, 21), (22, 22)]
WAVES = [(22, 24, 30, 0), (44, 18, 26, 0), (47, 20, 30, 3), (43, 45, 53, 1), (46, 48, 55, 4),   # (col, r0, r1, phase)
         (30, 15, 22, 2), (38, 15, 22, 5)]


def is_hair(v) -> bool:
    return v is not None and v.startswith("hair") and v != "hair_ink"


def wave(col: int, r0: int, r1: int, swing: int = 1, period: int = 6, phase: int = 0) -> list:
    cells = []
    for i, r in enumerate(range(r0, r1 + 1)):
        k = (i + phase) % period
        dx = 0 if k in (0, 1, period // 2, period // 2 + 1) else (swing if k < period // 2 else -swing)
        cells.append((r, col + dx))
    return cells


def fluff(hair: list) -> list:
    """Side puffs, curled lock ends, crown tufts, then wavy strand lines and shine over the hair pixels only."""
    paste_grid(hair, CROWN, LEGEND, 27, 9)
    paste_grid(hair, PUFF, LEGEND, 11, 25)
    paste_grid(hair, mirror(PUFF), LEGEND, 49, 25)
    paste_grid(hair, FLARE, LEGEND, 9, 46)
    paste_grid(hair, mirror(FLARE), LEGEND, 50, 46)
    for col, r0, r1, phase in WAVES:
        for r, c in wave(col, r0, r1, phase=phase):
            if 0 <= r < ROWS and 0 <= c < COLS and hair[r][c] in ("hair_light", "hair_mid"):
                hair[r][c] = "hair_shadow"
    for r, c in SHINE:
        if is_hair(hair[r][c]):
            hair[r][c] = "eye_white"
    return hair


def back_skirt() -> list:
    """The pale-blue layered skirt behind the body: a flare from row 44 (cols 22–45) to cols 8–59 at row 61,
    a gold cord at row 57, a white rim at row 61 with scallops hanging to row 63. The visible
    parts are beside the curls and under the front hem, behind the legs."""
    g = blank()
    edges = {r: (33 - (11 + (r - 44) * 14 // 17), 34 + (11 + (r - 44) * 14 // 17)) for r in range(44, 62)}   # half 11 → 25
    for r in range(44, 62):
        c0, c1 = edges[r]
        for c in range(c0, c1 + 1):
            g[r][c] = "dress_shade" if r < 50 else "accent_b"
        g[r][c0] = g[r][c1] = "outline"
    for c in range(edges[57][0] + 1, edges[57][1]):
        g[57][c] = "accent_a"
    c0, c1 = edges[61]
    for c in range(c0, c1 + 1):
        depth = {0: 0, 1: 1, 2: 2, 3: 2, 4: 1, 5: 0}[(c - c0) % 6]
        g[61][c] = "outline" if c in (c0, c1) else "eye_white"
        for r in range(62, 62 + depth):
            g[r][c] = "eye_white"
        g[62 + depth][c] = "outline"
    return g


def dress(body: list) -> list:
    """Gold dots on the waist band, a gold cord down the bodice, blue lace on the hem, cuff lines on the sleeves."""
    for c in range(24, 45, 3):
        if body[50][c] == "dress_trim":
            body[50][c] = "accent_a"
    for r in range(43, 50):
        if body[r][33] in ("dress_white", "dress_shade"):
            body[r][33] = "accent_a"
    for c in (26, 27, 30, 31, 34, 35, 38, 39):
        if body[56][c] in ("dress_white", "dress_shade"):
            body[56][c] = "dress_trim"
    for c in range(24, 45, 3):
        if body[57][c] == "dress_trim":
            body[57][c] = "dress_white"
    for r, c in ((55, 26), (55, 41), (54, 26), (54, 41)):
        if body[r][c] in ("dress_white", "dress_shade"):
            body[r][c] = "dress_trim"
    return body


def recipe() -> Recipe:
    hair = fluff(hair_from("rowena-rig"))
    paste_grid(hair, BUD, LEGEND, 45, 36)
    circlet = paste_grid(blank(), CHAIN, LEGEND, 20, 13)
    paste_grid(circlet, GEM, LEGEND, 31, 14)
    paste_grid(paste_grid(circlet, BEAD, LEGEND, 25, 14), BEAD, LEGEND, 40, 14)
    flowers = paste_grid(paste_grid(blank(), BLOSSOM, LEGEND, 15, 18), mirror(BLOSSOM), LEGEND, 43, 18)
    colours = base_colours(
        hair_light="#F7F8FF", hair_mid="#D5D9F0", hair_shadow="#AEB4DB", hair_deep="#7F86B8", hair_deeper="#7F86B8",
        blush="#F1B3C2", brow_soft="#F1B3C2", mouth_soft="#F1B3C2", ribbon_light="#F1B3C2",
        mouth="#8E5570", brow="#8E5570", ribbon_dark="#8E5570",
        eye_white="#F7F8FF", sock="#F7F8FF", dress_white="#F7F8FF", dress_shade="#E3E6F6",
        dress_trim="#6F8BE8", ribbon_mid="#6F8BE8", accent_b="#C3D0F4",
        iris_hi="#C9D0FF", iris_lo="#7A7FDB", pupil="#2A2C5E", shoe="#2A2C5E",
        accent_a="#E6C46A",
        outline="#04060F", ink="#171A34", hair_ink="#171A34")
    return Recipe("iris", "Iris", colours, dress(body_with_skull()),
                  front=[Part(hair, root=12), Part(circlet, "rigid"), Part(flowers, "rigid")],
                  back=[Part(back_skirt(), root=41, scale=0.5, cap=2)])
