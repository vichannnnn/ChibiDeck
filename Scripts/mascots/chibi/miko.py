"""Miko — a shrine maiden after dusk: hi-bit-shoujo's flared long cut in plum-black with a violet sheen and white
glints on the crown, a white kitsune mask worn on the upper right side of her head and seen in profile (ears at its
upper left above the hair, forehead sloping right into a long muzzle with a pointed snout past the hair's edge, the jaw
and the mask's left third tucked BEHIND the hair, the lower half shaded grey-lavender, one angled eye slit with a red
mark; traced from ref-03 in round seven), a layered red camellia with a gold heart and a leaf hanging at the mask's
lower-left base where it meets the hair, a white kimono top with red cords and a gold bell, and pleated red hakama
under a white sash. Theme shrine-dusk (tap order 2). Reference: the user's ref-03. Refinement round 2026-09-08."""
from __future__ import annotations

from parts import ACC, base_colours, body_with_skull
from rig import COLS, ROWS, Part, Recipe, blank, hair_from, paste_grid

# legend: parts.ACC — o outline · W white · M red (ribbon_mid) · k ink · E ribbon_light · A gold (accent_a) · d hair_deep

KITSUNE = [                 # 15×14 fox mask WORN ON THE SIDE of the head, traced from ref-03 (round seven, "follow
    "..oo..oo.......",          # exactly the shape in the chibi original"; round eight: two thirds the size, "too big"):
    ".oMMooWWo......",          # seen in profile facing right and down — the two ears rise at the upper LEFT (back ear
    ".oMWWoWWWo.....",          # red-tipped, front ear white, a red knot at their base), the forehead slopes down to
    "oMWWWWWWWWo....",          # the right into a long muzzle that ends in a pointed snout at the lower right, the jaw
    "oWWWMMWWWWWo...",          # runs back up-left under it, the lower half is shaded grey-lavender, one angled eye
    "oWWWWWWWWWWWo..",          # slit with a red mark above it
    "oPWWWWWWWMMWWo.",
    "oPPWWWWWWWkkWWo",
    ".oPPPWWWWWWWkWo",
    ".oPPPPPWWWWWWWo",
    "..oPPPPPPPPPPWo",
    "..oPPPPPPPPPoo.",
    "...oPPPPPPoo...",
    "....oooooo.....",
]
CAMELLIA = [                # 10×10: two rings of petals, light rims on the upper left, a gold heart with a dark centre
    "...oooo...",
    "..oMEMMo..",
    ".oMEMMEMo.",
    "oMEMMMMEMo",
    "oMMMAAMMMo",
    "oEMMAkAMEo",
    "oMMMAAMMMo",
    ".oMEMMEMo.",
    "..oMMMMo..",
    "...oooo...",
]
LEAF = [                    # tucks under the camellia's lower left
    "odo",
    "ddo",
    "oo.",
]
BELL = [                    # a gold bell on the chest cords (torso: does not nod)
    ".oo.",
    "oAAo",
    "oAAo",
    ".oko",
]


def thin_sheen(hair: list, keep: int = 2) -> list:
    """Dark hair: every run of hair_light keeps only its first `keep` pixels; the rest of the run turns hair_mid, so the
    donor's broad light planes become a violet sheen along the left edge of each strand."""
    for row in hair:
        run = 0
        for c in range(COLS):
            if row[c] == "hair_light":
                run += 1
                if run > keep:
                    row[c] = "hair_mid"
            else:
                run = 0
    return hair


def is_hair(v) -> bool:
    return v is not None and v.startswith("hair") and v != "hair_ink"


def stroke(layer: list, cells: list, role: str) -> list:
    """Paint `role` on the given (row, col) cells, but only where the layer already has hair — never over air or outline."""
    for r, c in cells:
        if 0 <= r < ROWS and 0 <= c < COLS and is_hair(layer[r][c]):
            layer[r][c] = role
    return layer


def vertical(col: int, r0: int, r1: int) -> list:
    return [(r, col) for r in range(r0, r1 + 1)]


def detail_hair(hair: list) -> list:
    """Shine on the crown, hair_light sheen strokes, and strand lines in the fringe and the flared locks."""
    stroke(hair, [(13, 28), (13, 29), (14, 27), (12, 34), (12, 35)], "eye_white")            # glints
    stroke(hair, [(14, 28), (14, 29), (14, 30), (14, 31), (15, 32), (16, 24), (16, 25), (16, 26)], "hair_light")
    for col, r0, r1 in ((22, 25, 30), (36, 24, 28), (20, 44, 50), (23, 46, 52), (47, 44, 50), (50, 46, 52),
                        (18, 33, 38), (46, 23, 30)):
        stroke(hair, vertical(col, r0, r1), "hair_ink")
    return hair


def hakama(body: list) -> list:
    """Row 51 becomes a white sash; rows 52–56 red hakama with three dark pleat lines."""
    for c in range(COLS):
        if body[51][c] in ("dress_white", "dress_shade"):
            body[51][c] = "dress_white"
    for r in range(52, 57):
        for c in range(COLS):
            if body[r][c] == "dress_white":
                body[r][c] = "accent_b"
            elif body[r][c] == "dress_shade":
                body[r][c] = "ribbon_dark"
        for c in (30, 34, 38):
            if body[r][c] in ("accent_b",):
                body[r][c] = "ribbon_dark"
    return body


def recipe() -> Recipe:
    mask = paste_grid(blank(), KITSUNE, ACC, 40, 7)      # a back part: the hair covers its left third and the jaw
    hair = detail_hair(thin_sheen(hair_from("hi-bit-shoujo")))
    flower = paste_grid(paste_grid(blank(), LEAF, ACC, 42, 25), CAMELLIA, ACC, 44, 18)   # at the mask's lower-left base
    bell = paste_grid(blank(), BELL, ACC, 32, 43)
    colours = base_colours(
        hair_light="#A98AA8", hair_mid="#4A3050", hair_shadow="#33203A", hair_deep="#221426", hair_deeper="#221426",
        dress_white="#FFFFFF", eye_white="#FFFFFF", sock="#FFFFFF", dress_shade="#ECDDE0", dress_trim="#D8323A",
        accent_b="#D8323A", ribbon_mid="#D8323A", accent_a="#F2C55C",
        iris_hi="#F58CB0", iris_lo="#C93A6E", pupil="#3A0F22", shoe="#3A0F22",
        blush="#F2A0A8", brow_soft="#F2A0A8", mouth_soft="#F2A0A8", ribbon_light="#F2A0A8",
        mouth="#8C1E28", brow="#8C1E28", ribbon_dark="#8C1E28",
        ink="#12080F", hair_ink="#12080F", outline="#07040A")
    return Recipe("miko", "Miko", colours, hakama(body_with_skull()),
                  front=[Part(hair, root=12), Part(flower, "rigid"), Part(bell, "rigid", nod=False)],
                  back=[Part(mask, "rigid", nod=True)])
