"""Rosalie — frost roses (round three): Sprite Shoujo's shoulder bob mirrored and recoloured light blue, with a gleam,
fine wave strand lines and the lock ends flipping gently outward at the shoulders; a thin crown braid — a 3-px band of
light/mid/shadow chevrons along the hairline from temple to temple, an ink line under it — whose ends hide under a big
red rose with dark petal lines and a green leaf pair at each temple (round seven; the earlier loops and side plaits are
gone); a navy cape with a mid-blue lining hanging behind her that sways; a white dress with pale blue bow, light-blue
trim bands, lace and a gold bell at the collar; white stockings with a blue garter band, a blue strap and a gold ankle
bell; blue shoes. Theme rose-frost (tap order 8). Reference: the user's ref-08."""
from __future__ import annotations

from parts import ACC, base_colours, body_with_skull, erase_rows
from rig import COLS, ROWS, Part, Recipe, blank, hair_from, mirror, paste_grid

# legend: parts.ACC — o outline · M red (ribbon_mid) · E rose light (ribbon_light)
# F rose dark (ribbon_dark) · i leaf (ear_inner) · w gold (tail_tip) · A cape navy · B cape lining · S dress_trim

ROSE = [                    # red rose, 11 × 8, with a two-leaf sprig at the lower left (rows 8–10)
    "...ooooo...",
    "..oMEEMMo..",
    ".oMEMMFMMo.",
    "oMEMFFFMEMo",
    "oMMFMEMFMMo",
    "oMMFMFFFMEo",
    "oEMMFMMMMMo",
    ".oMMMMMEMo.",
    "oioooooooo.",
    "oiiio......",
    ".oooo......",
]
BELL = [                    # gold bell over the bow knot
    "..o..",
    ".owo.",
    ".owo.",
    "owwwo",
    "owkwo",
    ".ooo.",
]
CAPE = [                    # cols 16–52, rows 41–60: navy behind the body, lining along the edge, hem below the dress
    "........ooooooooooooooooooooo........",
    ".......oBAAAAAAAAAAAAAAAAAAABo.......",
    "......oBAAAAAAAAAAAAAAAAAAAAABo......",
    ".....oBAAAAAAAAAAAAAAAAAAAAAAABo.....",
    "....oBAAAAAAAAAAAAAAAAAAAAAAAAABo....",
    "....oBAAAAAAAAAAAAAAAAAAAAAAAAABo....",
    "...oBAAAAAAAAAAAAAAAAAAAAAAAAAAABo...",
    "...oBAAAAAAAAAAAAAAAAAAAAAAAAAAABo...",
    "..oBAAAAAAAAAAAAAAAAAAAAAAAAAAAAABo..",
    "..oBAAAAAAAAAAAAAAAAAAAAAAAAAAAAABo..",
    ".oBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABo.",
    ".oBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABo.",
    "oBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABo",
    "oBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABo",
    "oBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABo",
    "oBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABo",
    "oBBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBo",
    "oBBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBo",
    "oBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBo",
    ".ooooooooooooooooooooooooooooooooooo.",
]

SHINE = [(14, 25), (14, 26), (14, 27), (15, 24), (15, 25), (16, 23),           # gleam on the upper left of the crown
         (15, 41), (15, 42), (16, 43)]
STRANDS = [(19, 22), (20, 22), (21, 23), (22, 23), (19, 45), (20, 45), (21, 44), (22, 44),
           (26, 20), (27, 20), (28, 21), (43, 21), (44, 21), (45, 22), (43, 47), (44, 47), (45, 46),
           (36, 22), (37, 23), (38, 23), (39, 22), (36, 46), (37, 45), (38, 45), (39, 46)]   # waves down both locks
PLAIT = ["hair_light", "hair_mid", "hair_shadow"]


def detail(hair: list) -> list:
    for r, c in SHINE:
        if hair[r][c] is not None and hair[r][c].startswith("hair"):
            hair[r][c] = "eye_white"
    for r, c in STRANDS:
        if hair[r][c] in ("hair_light", "hair_mid"):
            hair[r][c] = "hair_shadow"
    return hair


FLIPS = [                   # the lock ends flip outward at the shoulders: (row, col, role) written over the layer
    (44, 15, "outline"), (44, 16, "hair_mid"),
    (45, 14, "outline"), (45, 15, "hair_light"), (45, 16, "hair_light"),
    (46, 15, "outline"), (46, 16, "hair_shadow"), (46, 17, "hair_light"),
    (44, 49, "hair_light"), (44, 50, "outline"),
    (45, 48, "hair_light"), (45, 49, "hair_light"), (45, 50, "outline"),
    (46, 47, "hair_shadow"), (46, 48, "hair_light"), (46, 49, "outline"),
]


def crown_braid(hair: list, c0: int = 21, c1: int = 46) -> list:
    """A 3-px plaited band along the hairline: in each column it sits just under the hair's top outline, so it follows
    the skull's curve; a diagonal light/mid/shadow weave two columns wide, and an ink line under it. The ends run
    under the roses at the temples."""
    for c in range(c0, c1 + 1):
        top = next((r for r in range(ROWS) if hair[r][c] is not None), None)
        if top is None:
            continue
        for depth in range(3):
            r = top + 1 + depth
            if r < ROWS and hair[r][c] is not None:
                hair[r][c] = PLAIT[((c // 2) + depth) % 3]      # diagonal weave: the plait reads at 280 px
        r = top + 4
        if r < ROWS and hair[r][c] is not None and hair[r][c] != "outline":
            hair[r][c] = "hair_ink"
    return hair


def flip_ends(hair: list) -> list:
    for r, c, role in FLIPS:
        hair[r][c] = role
    return hair


def roses() -> list:
    """At the temples (rows 11–21), over the crown braid's ends."""
    g = paste_grid(blank(), ROSE, ACC, 13, 11)
    return paste_grid(g, mirror(ROSE), ACC, COLS - 13 - 11, 11)


def dress(body: list) -> list:
    """The chest bow goes pale blue, a gold bell hangs at the knot, lace dots above the hem, and the legs become
    stockings: white, a blue garter band, a diagonal strap and a gold ankle bell; the shoes stay the body's."""
    for r in range(41, 50):
        for c in range(COLS):
            if body[r][c] == "ribbon_light":
                body[r][c] = "dress_shade"
            elif body[r][c] == "ribbon_mid":
                body[r][c] = "dress_trim"
    paste_grid(body, BELL, ACC, 31, 41)
    for c in range(24, 45, 2):
        if body[56][c] in ("dress_white", "dress_shade"):
            body[56][c] = "dress_trim"
    for r in range(59, 64):
        for c in range(COLS):
            if body[r][c] == "skin" or body[r][c] == "sock":
                body[r][c] = "dress_trim" if r == 59 else "sock"
    for (r, c) in ((60, 29), (61, 30), (62, 31), (60, 38), (61, 37), (62, 36)):
        body[r][c] = "dress_trim"
    body[63][29] = body[63][38] = "tail_tip"
    return body


def recipe() -> Recipe:
    hair = crown_braid(flip_ends(detail(erase_rows([row[::-1] for row in hair_from("sprite-shoujo")], 3, 9))))
    cape = paste_grid(blank(), CAPE, ACC, 16, 41)
    colours = base_colours(
        hair_light="#F4F8FF", eye_white="#F4F8FF", dress_white="#F4F8FF", sock="#F4F8FF",
        hair_mid="#BFDDF7", hair_shadow="#8FBCE8", dress_trim="#8FBCE8", hair_deep="#5E8FC4", hair_deeper="#5E8FC4",
        accent_b="#5E8FC4", dress_shade="#D6E4F7", iris_hi="#D6E4F7",
        ribbon_mid="#D8323A", ribbon_light="#F29AA0", ear_inner="#4F9A5E", tail_tip="#E9BE4E",
        iris_lo="#5B7FD9", shoe="#5B7FD9", pupil="#1F2A5C", accent_a="#1F2A5C",
        blush="#F3AEB8", brow_soft="#F3AEB8", mouth_soft="#F3AEB8", mouth="#9A4A5A", brow="#9A4A5A", ribbon_dark="#9A4A5A",
        ink="#141B3A", hair_ink="#141B3A", outline="#05081A")
    return Recipe("rosalie", "Rosalie", colours, dress(body_with_skull()),
                  front=[Part(hair, root=12), Part(roses(), "rigid")],
                  back=[Part(cape, root=41, scale=0.5, cap=2)])
