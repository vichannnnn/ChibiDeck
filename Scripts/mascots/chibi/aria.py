"""Aria — an idol in black and white (round three redo, 2026-09-08): white twintails, a big black rose pinned into the
hair at her upper right with a sheer black ribbon streaming from it, a black gown that is the point of the design — a wide back skirt
flaring behind her with a white lace hem and fold shadows, a black bodice with a white frill tier, white cuffs, a white
chest bow and white cords fanning down the front skirt — and a microphone held up in her left hand.

Reference: the white-haired singer with the black rose and the microphone (ref-06, ref-11). The user's round-two note:
"She should be black themed. The hair should have the black flower hairpin, and the dress should be prominent"; the hair
stays white (their answer). Theme `stage-noir` (tap order 4). Hair: the twintail donor in white (hair_light is the
white); the tails are free locks (stretch=False). The tiara and the tail bows of round two are gone (ref-11 has
neither); the back skirt is a back part that sways a little under the body. A block of back hair behind the shoulders
(back layer) still fills the air beside the torso that the swinging tails used to open into holes."""
from rig import COLS, Part, Recipe, blank, hair_from, mirror, paste_grid
from parts import ACC, base_colours, body_with_skull

# legend: parts.ACC plus N dress_white (the black gown), J iris_lo — o outline · k ribbon_mid (petal) · M ink (petal crevice) ·
# E ribbon_light (petal rim) · W eye_white (white) · P dress_shade · S dress_trim (white lace) · s hair_shadow · d hair_deep
LEGEND = dict(ACC, N="dress_white", J="iris_lo", k="ribbon_mid", M="ink")   # petals: mid tone, ink crevices

ROSE = [                    # 13 wide, 14 rows: a black rose — dark violet-black petals, ink crevices between them, rim
    ".....ooo.....",         # highlights on the lit (upper-right, after mirroring) side, a rolled centre; pasted mirrored
    "...ookkkoo...",         # at cols 37–49, rows 7–20 so it sits IN the white hair at her upper right like ref-06 / ref-11
    "..okkEkkkkko.",
    ".okkEkMMkkkko",
    ".okEkMkkMkkko",
    "okkEkMkEkMkko",
    "okkkEkMMkkkko",
    "okkkkEkkkkkko",
    ".okkMkkEEkkko",
    ".okkkMMkkkkoo",
    "..ookkkkkkkko",
    "....ookkkkkoo",
    "......ooooo..",
    ".............",
]
RIBBON = [                  # 15 wide, 17 rows at cols 46–60, rows 8–24: ref-11's sheer black ribbon streaming from the
    "...oooo........",       # flower — two loops at the rose and one wide sheer tail hugging the rose, then trailing right and
    "..okEEko.......",       # down past the hair's edge (a narrower tail enclosed a window against the twintail). Mid tone k (reads as sheer black on the dark ground), rim highlights
    "..okkkkoo......",       # E, ink creases M, 1-px outline. A bend part rooted at the loops (scale 0.5, cap 2), so it
    "...okkokEko....",       # sways as the secondary motion; drawn under the rose.
    "..ookkkkkkko...",
    "...ookkkkMkkoo.",
    "...okkkkkkMkko.",
    "...okEkkkkkMkko",
    "...okEkkkkkkMko",
    "...ookkkkkkkkMo",
    "......okEkkkkko",
    ".......okEkkkko",
    ".........okkEko",
    "..........okkko",
    "..........okkoo",
    "...........oko.",
    "...........oo..",
]
BACK_HAIR = [               # cols 36–48, rows 41–49, right side; mirror(BACK_HAIR) at cols 19–31. Back layer: the body covers
    "sssssssssssso",         # the middle, so what shows is a shaded lock behind each shoulder that narrows outward
    "sssssssssssso",
    "sssssssssssdo",
    "sssssssssdddo",
    "ooosssssddddo",
    "...oooosddddo",
    ".......oddddo",
    "........odddo",
    ".........oooo",
]
MIC = [                     # 9 wide, 17 rows: a 7×6 mesh head with a lit rim, a ring, a 2-px handle (hair_shadow) ending in
    "..ooooo..",             # the hand. Mirrored into the left hand (cols 19–27, rows 40–56). Held by the torso: nod=False.
    ".oWWkWko.",
    "oWkWkWkWo",
    "okWkWkWko",
    "oWkWkWkWo",
    ".okWkWko.",
    "..ooooo..",
    "...oEEo..",
    "...osso..",
    "...osso..",
    "...osso..",
    "...osso..",
    "...osso..",
    "...osso..",
    "...osso..",
    "...osso..",
    "...oooo..",
]


def back_skirt() -> list:
    """The gown's wide back skirt: rows 49–60, flaring from cols 20–48 to cols 12–56, black with fold shadows on the
    right and every seventh column, a two-row white lace hem with scallops, and a few white speckles like the fabric
    in the reference. A back part: the body and legs draw over its middle."""
    g = blank()
    for r in range(49, 58):
        left, right = 20 - (r - 49), 48 + (r - 49)
        for c in range(left, right + 1):
            if c in (left, right):
                g[r][c] = "outline"
            elif c >= right - 6 or (c - 12) % 7 == 3 and r >= 51:
                g[r][c] = "dress_shade"
            else:
                g[r][c] = "dress_white"
    for r, cs in ((52, (18, 24, 44)), (54, (15, 30, 51)), (56, (21, 37, 48))):
        for c in cs:
            if g[r][c] == "dress_white":
                g[r][c] = "eye_white"
    for c in range(12, 57):
        g[58][c] = "outline" if c in (12, 56) else "dress_trim"
        g[59][c] = "outline" if c in (12, 56) or c % 3 == 1 else "dress_trim"
        g[60][c] = "outline" if c % 3 != 1 else None
    return g


def detail_hair(hair: list) -> list:
    """Glossy strokes on the crown and strand lines down both tails and the fringe."""
    for r, cs in ((16, (26, 27, 28)), (17, (36, 37, 38)), (13, (30, 31))):
        for c in cs:
            if hair[r][c] not in (None, "outline"):
                hair[r][c] = "eye_white"
    for col, rows in ((11, range(20, 25)), (14, range(31, 37)), (12, range(37, 42)),
                      (53, range(20, 25)), (50, range(31, 37)), (52, range(37, 42)),
                      (22, range(26, 31)), (45, range(27, 32))):
        for r in rows:
            if hair[r][col] not in (None, "outline"):
                hair[r][col] = "hair_deep"
    return hair


def detail_body(body: list) -> list:
    """The black gown's front: white chest bow, white cuffs, white cords fanning from the waist down the skirt with
    small white gems at their ends, and a scalloped white hem."""
    for r in range(41, 45):                                   # chest bow: white loops, grey knot
        for c in range(COLS):
            if body[r][c] == "ribbon_light":
                body[r][c] = "dress_trim"
            elif body[r][c] == "ribbon_mid":
                body[r][c] = "hair_shadow"
    for r in range(51, 57):                                   # cuffs
        for c in range(COLS):
            if body[r][c] == "ribbon_light":
                body[r][c] = "dress_trim"
    for i in range(6):                                        # cords: two lines from the waist centre, one straight down
        r = 51 + i
        for c in (33 - i, 34 + i, 33 if i % 2 else 34):
            if body[r][c] in ("dress_white", "dress_shade"):
                body[r][c] = "dress_trim"
    for c in (27, 40):                                        # gems at the cord ends
        if body[56][c] in ("dress_white", "dress_shade"):
            body[56][c] = "eye_white"
    for c in range(24, 45, 3):                                # hem scallops
        if body[57][c] == "dress_trim":
            body[57][c] = "dress_shade"
    return body


def recipe() -> Recipe:
    hair = detail_hair(hair_from("twintail-hima"))
    hair[46][14] = "hair_shadow"          # close the 1-px gap between the left tail's tip strands
    ribbon = paste_grid(blank(), RIBBON, LEGEND, 46, 8)
    rose = paste_grid(blank(), mirror(ROSE), LEGEND, 37, 7)
    mic = paste_grid(blank(), mirror(MIC), LEGEND, 19, 40)
    back_hair = paste_grid(paste_grid(blank(), BACK_HAIR, LEGEND, 36, 41), mirror(BACK_HAIR), LEGEND, 19, 41)
    colours = base_colours(
        hair_light="#FFFFFF", hair_mid="#ECEAF4", hair_shadow="#CBC5DC", hair_deep="#9A93B8", hair_deeper="#9A93B8",
        eye_white="#FFFFFF", sock="#FFFFFF", dress_trim="#FFFFFF",
        dress_white="#2A2340", dress_shade="#1A1528",
        ribbon_mid="#3A3250", ribbon_light="#8A82A8", ribbon_dark="#100C18",
        iris_hi="#DCC2FF", iris_lo="#8F63D2", pupil="#2A1842", shoe="#2A1842",
        blush="#F2A9C0", brow_soft="#F2A9C0", mouth_soft="#F2A9C0", mouth="#8C4A6A", brow="#8C4A6A",
        outline="#05040A", ink="#100C18", hair_ink="#100C18")
    return Recipe("aria", "Aria", colours, detail_body(body_with_skull()),
                  front=[Part(hair, root=12, stretch=False), Part(ribbon, root=8, scale=0.5, cap=2), Part(rose, "rigid"),
                         Part(mic, "rigid", nod=False)],
                  back=[Part(back_skirt(), root=49, scale=0.5, cap=1), Part(back_hair, "rigid")])
