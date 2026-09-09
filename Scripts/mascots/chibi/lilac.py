"""Lilac — lavender hair with pink streaks fading to pink tips, a pink star bow pinned in the hair; theme wonderland
(tap order 5).

Reference: the user's ref-07 (2026-09-08): lavender-to-pink hair, a huge pink bow with a gold star, playing cards, a teacup.
Round three (the user: "the ribbon is too out of place, make it more like a hairpin because it's currently outside of the
hair; refine everything in general"): the bow now sits on the hair itself — its left two thirds over the upper-right of the
head, the knot at col 43, rows 11–19 — with a gold five-point star on the knot, and its tails hang down the right side of
the hair. Hair: Hi-Bit Shoujo's flared long cut in lavender with white shine strokes, shadow strands, three pink streaks
(two rows wide, the reference's inner streaks) and a dithered pink fade from row 46. Lavender dress (the reference's) with
white bands, pink dots on the hem, a shade fold; a playing card with a pink heart in the right hand (torso part: no nod).
Violet eyes; pupils and shoes take the ink colour; the dress shares the hair's lavender slots (16-slot budget)."""
from rig import COLS, Part, Recipe, blank, hair_from, paste_grid
from parts import ACC, base_colours, body_with_skull, remap_below

BOW = [                     # 19×9: two tapered loops (M, E, W rim on top, A underside) around a 5-wide knot with a gold star
    ".ooo...........ooo.",
    "oWWMo.........oMWWo",
    "oEMMMoo.....ooMMMEo",
    "oEMMMMooooooooMMMAo",
    "oMMMMMoAABAAoMMMMAo",
    "oMMMMAoBBBBBoMMMAAo",
    "oAMMAAoABBBAoMMAAAo",
    "oAAAAooB.A.BoAAAAo.",
    ".oooo..ooooo..oooo.",
]
TAILS = [                   # 7×9: two ribbon tails side by side under the knot, sharing their inner outline (no slit to enclose)
    "oMMoMMo",
    "oMMoMMo",
    "oMAoMAo",
    "oMMoMMo",
    "oMMoMMo",
    "oMAoMAo",
    "oMMoMMo",
    "oAMoMAo",
    ".ooooo.",
]
CARD = [                    # 4×6 playing card in the right hand: white with a pink heart
    "oooo",
    "oWWo",
    "oWMo",
    "oMWo",
    "oWWo",
    "oooo",
]
SHINE = [(13, 27, 29), (15, 25, 26), (12, 33, 34)]           # (row, first col, last col) white strokes on the crown
STREAKS = [(20, 20), (21, 20), (22, 21), (23, 21), (24, 22), (25, 22), (26, 22),      # pink inner streaks, two px wide
           (14, 31), (15, 31), (16, 32), (17, 32), (18, 33), (19, 33),
           (22, 44), (23, 44), (24, 45), (25, 45), (26, 45), (27, 45)]
STRANDS = [(19, 24), (20, 24), (21, 25), (22, 25), (23, 26),  # shadow strands through the flat planes and down the locks
           (18, 37), (19, 37), (20, 38), (21, 38),
           (43, 21), (44, 21), (45, 22), (46, 22),
           (44, 46), (45, 46), (46, 47), (47, 47)]


def detail_hair(hair: list) -> list:
    for r, c0, c1 in SHINE:
        for c in range(c0, c1 + 1):
            hair[r][c] = "eye_white"
    for r, c in STRANDS:
        if hair[r][c] is not None and hair[r][c].startswith("hair"):
            hair[r][c] = "hair_shadow"
    for r, c in STREAKS:
        for cc in (c, c + 1):
            if hair[r][cc] is not None and hair[r][cc].startswith("hair") and hair[r][cc] != "hair_deep":
                hair[r][cc] = "ribbon_light" if cc == c else "ribbon_mid"
    return hair


def detail_dress(body: list) -> list:
    """White bands with pink dots on the hem, a fold shadow in the skirt, a white collar line."""
    for c in range(COLS):
        if body[57][c] == "dress_trim" and (c - 23) % 3 == 1:
            body[57][c] = "ribbon_mid"
        if body[50][c] == "dress_trim" and (c - 23) % 4 == 2:
            body[50][c] = "dress_shade"
    for r in range(52, 57):
        if body[r][36] == "dress_white":
            body[r][36] = "dress_shade"
    return body


def recipe() -> Recipe:
    hair = detail_hair(hair_from("hi-bit-shoujo"))
    remap_below(hair, 46, {"hair_light": "ribbon_light", "hair_mid": "ribbon_mid", "hair_shadow": "accent_a"}, fade=4)
    bow = paste_grid(blank(), BOW, ACC, 34, 11)
    tails = paste_grid(blank(), TAILS, ACC, 40, 20)
    card = paste_grid(blank(), CARD, ACC, 45, 49)
    body = detail_dress(body_with_skull())
    colours = base_colours(
        outline="#07050F", ink="#17112C", hair_ink="#17112C",
        hair_light="#EFE6FF", hair_mid="#CDBAF6", hair_shadow="#A78FE3", hair_deep="#7F63C4", hair_deeper="#7F63C4",
        ribbon_light="#FFC4E8", ribbon_mid="#FF86CC", accent_a="#DE5AA8", accent_b="#FFD45C",
        blush="#F5AACB", brow_soft="#F5AACB", mouth_soft="#F5AACB",
        mouth="#8F4B7A", brow="#8F4B7A", ribbon_dark="#8F4B7A",
        eye_white="#FFFFFF", sock="#FFFFFF", dress_white="#CDBAF6", dress_shade="#A78FE3", dress_trim="#FFFFFF",
        iris_hi="#F2BDFF", iris_lo="#B064DB", pupil="#17112C", shoe="#17112C")
    return Recipe("lilac", "Lilac", colours, body,
                  front=[Part(hair, root=12), Part(bow, "rigid"),
                         Part(tails, root=20, scale=0.5, cap=2),
                         Part(card, "rigid", nod=False)])
