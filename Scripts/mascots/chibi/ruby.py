"""Ruby — black hair in two big odango buns, orange streaks, a red cropped jacket over a dark top; theme lantern-red (tap order 1).

Reference: the user's ref-02 (2026-09-08): black hair in two large buns on the upper corners of the head, orange streaks
running through the buns, the fringe and the locks, gold paper ribbons hanging at the base of each bun, a red short
jacket with orange cuffs over a black top, a white frilled hem, red waist ribbons and black stockings.
Round three (2026-09-08): "The hair should have a proper bun and the shirt should be redone. Hairstyle should have the
streaks of hairs as well." Two buns (the user's choice). Hair: Rowena Rig's long straight cut in near-black with a violet
sheen, white shine strokes on the crown, orange streaks (accent_a) in the fringe and down both locks plus thin ink strands;
only the lock ends beside the white frill (rows 55–57) turn orange (round five). Each bun is 13×11 in four tones with an orange streak; a gold ribbon
hangs from its outer base and sways (a free bend part). The jacket: red with orange lapels and cuffs, a black inner top,
a dark belt with a gold buckle, red skirt, white frill with grey scallops, a red waist ribbon that sways (held by the
torso), black stockings and shoes. Orange eyes; pupils and shoes take the ink colour (16-slot budget)."""
from rig import COLS, ROWS, Part, Recipe, blank, hair_from, mirror, paste_grid
from parts import ACC, base_colours, body_with_skull, remap_below

LEGEND = dict(ACC, R="dress_white")          # R: the dress red (waist ribbon)

BUN = [                     # 13×11 black bun: one shine stroke upper left, an orange streak curling round its left side
    "....ooooo....",
    "..oommmmmoo..",
    ".ollmmmmmmso.",
    ".olmmmmmmsso.",
    "omAmmmmmmssso",
    "omAAmmmmmsssdo"[:13],
    "ommAAmmmssssdo"[:13],
    "ossmAAmmsssddo"[:13],
    ".osssAAssdddo",
    ".oosssssdddoo",
    "..ooooooooo..",
]
GOLD_RIBBON = [             # 5×8 folded paper ribbon hanging from the bun's outer base (left side; mirrored on the right)
    ".oo..",
    "oSEo.",
    "oSSo.",
    ".oSSo",
    ".oSEo",
    ".oSSo",
    "..oSo",
    "..oo.",
]
WAIST_RIBBON = [            # 3×8 red ribbon hanging from the belt over the skirt
    "oRo",
    "oRo",
    "oRo",
    "oRo",
    "oRo",
    "oRo",
    "oRo",
    ".o.",
]
SHINE = [(13, 29, 31), (15, 28, 29)]                          # (row, first col, last col) white strokes on the crown
STREAKS = ([(r, 39 + (r >= 21)) for r in range(17, 25)]                              # one long streak over the fringe
           + [(r, 19 + (r >= 36)) for r in range(29, 39)]                             # down the left lock (ends above the jacket)
           + [(r, 46 + (r >= 34)) for r in range(26, 38)]                             # down the right lock
           + [(12 + i, 25 + i // 2) for i in range(6)])                               # a short one from the crown
STRANDS = [(18, 21), (19, 21), (20, 22), (21, 22), (22, 23),  # ink strands through the flat planes
           (19, 38), (20, 38), (21, 39), (22, 39),
           (42, 17), (43, 17), (44, 18), (45, 18), (46, 18),
           (41, 48), (42, 48), (43, 48), (44, 48), (45, 48)]


def tame_sheen(hair: list) -> list:
    """Black hair: the donor's broad light areas become hair_mid; the light tone stays only as the crown sheen (rows 11–17)
    and a sliver along the top of the fringe (rows 24–25), the anime highlight band."""
    for r in range(ROWS):
        for c in range(COLS):
            if hair[r][c] == "hair_light" and not (r <= 17 or 24 <= r <= 25):
                hair[r][c] = "hair_mid"
    return hair


def is_hair(v) -> bool:
    return v is not None and v.startswith("hair") and v != "hair_ink"


def detail_hair(hair: list) -> list:
    for r, c0, c1 in SHINE:
        for c in range(c0, c1 + 1):
            hair[r][c] = "eye_white"
    for r, c in STREAKS:
        if is_hair(hair[r][c]):
            hair[r][c] = "accent_a"
    for r, c in STRANDS:
        if is_hair(hair[r][c]):
            hair[r][c] = "hair_ink"
    return hair


def edge_locks(hair: list) -> list:
    """Round five: from the collar down, the innermost pixel of each lock takes the outline colour so the black hair keeps a
    crisp edge over the red jacket and skirt in every frame (the donor's inner edge is hair_deep there)."""
    for r in range(41, ROWS):
        segs = [(c0, c1) for c0, c1 in __import__("rig").segments(hair[r]) if c1 - c0 >= 2]
        if not segs:
            continue
        left = min(segs, key=lambda s: s[0]); right = max(segs, key=lambda s: s[1])
        if left[1] < 34:
            hair[r][left[1]] = "outline"
        if right[0] > 33 and right is not left:
            hair[r][right[0]] = "outline"
    return hair


def outfit(body: list) -> list:
    """The jacket over a black top (rows 41–49), belt (50), red skirt (51–54), white frill (55–57), black stockings (59–65)."""
    for c in range(COLS):                                   # collar: gold edge
        if body[41][c] in ("dress_trim", "ribbon_light", "ribbon_mid"):
            body[41][c] = "dress_trim"
    for r in range(42, 50):                                 # black top in a V that narrows to the belt, orange lapels
        half = max(0, 3 - (r - 42) // 2)                    # rows 42–43: cols 30–37 … rows 48–49: cols 33–34
        lo, hi = 33 - half, 34 + half
        for c in range(lo, hi + 1):
            if body[r][c] is not None and body[r][c] != "outline":
                body[r][c] = "ink"
        for c in (lo - 1, hi + 1):
            if body[r][c] is not None and body[r][c] != "outline":
                body[r][c] = "accent_a"
    for r in range(42, 50):                                 # the rest of the bodice is jacket red
        for c in range(COLS):
            if body[r][c] in ("ribbon_light", "ribbon_mid", "dress_trim", "dress_shade") and body[r][c] != "ink":
                body[r][c] = "dress_white"
    for r, cols in ((48, (24, 25, 26, 41, 42, 43)), (49, tuple(range(24, 29)) + tuple(range(39, 44)))):   # orange cuffs
        for c in cols:
            if body[r][c] not in (None, "outline"):
                body[r][c] = "accent_a"
    for c in range(COLS):                                   # dark belt with a gold buckle
        if body[50][c] == "dress_trim":
            body[50][c] = "dress_trim" if 32 <= c <= 35 else "ink"
    for r in range(51, 57):                                 # waist ribbons hang red, not pink
        for c in range(COLS):
            if body[r][c] == "ribbon_light":
                body[r][c] = "dress_white"
    for r in range(55, 58):                                 # white frill, grey scallops on the hem row
        for c in range(26, 44):
            if body[r][c] in ("dress_white", "dress_shade", "dress_trim"):
                body[r][c] = "hair_light" if r == 57 and c % 3 == 1 else "eye_white"
    for r in range(59, 66):                                 # black stockings, an ink band at the top, ink shoes
        for c in range(COLS):
            if body[r][c] in ("skin", "sock"):
                body[r][c] = "ink" if r == 59 else "hair_shadow"
            elif body[r][c] == "shoe":
                body[r][c] = "ink"
    return body


def recipe() -> Recipe:
    hair = edge_locks(detail_hair(tame_sheen(hair_from("rowena-rig"))))
    # Round five ("the hair is merging into the outfit"): the locks stay black beside the red skirt; only the ends that hang
    # beside the white frill (rows 55–57) turn orange, in the light orange alone so they never read as jacket red.
    remap_below(hair, 55, {"hair_light": "accent_a", "hair_mid": "accent_a", "hair_shadow": "accent_a", "hair_deep": "accent_a", "hair_deeper": "accent_a"}, fade=0)
    buns = blank()
    paste_grid(buns, BUN, LEGEND, 17, 5)
    paste_grid(buns, mirror(BUN), LEGEND, 38, 5)
    ribbons = blank()
    paste_grid(ribbons, GOLD_RIBBON, LEGEND, 16, 14)
    paste_grid(ribbons, mirror(GOLD_RIBBON), LEGEND, 47, 14)
    waist = paste_grid(blank(), WAIST_RIBBON, LEGEND, 35, 51)
    body = body_with_skull()
    body[51][44], body[51][45] = "skin", "outline"   # the notch above the right cuff that Rowena's lock leaves open
    outfit(body)
    colours = base_colours(
        outline="#060508", ink="#120F14", hair_ink="#120F14",
        hair_light="#A39CB8", hair_mid="#3A3644", hair_shadow="#29252F", hair_deep="#1A171F", hair_deeper="#1A171F",
        accent_a="#F0803F", accent_b="#C2481C", iris_hi="#F0803F", iris_lo="#C2481C", pupil="#120F14", shoe="#120F14",
        blush="#F0A0A0", brow_soft="#F0A0A0", mouth_soft="#F0A0A0",
        mouth="#8E2A22", brow="#8E2A22", ribbon_dark="#8E2A22",
        eye_white="#FFFFFF", sock="#FFFFFF",
        dress_white="#C4262C", dress_shade="#951A20", dress_trim="#F2C94C", ribbon_mid="#F2C94C", ribbon_light="#FBE7A8")
    return Recipe("ruby", "Ruby", colours, body,
                  front=[Part(hair, root=12), Part(buns, "rigid"),
                         Part(ribbons, root=14, scale=0.5, cap=2, stretch=False),
                         Part(waist, root=50, scale=0.5, cap=2, nod=False)])
