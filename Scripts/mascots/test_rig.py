#!/usr/bin/env python3
"""Unit tests for the mascot rig (spec 2026-09-08 §8).

Run from the repo root: python3 -m unittest discover -s Scripts/mascots -p 'test_*.py'
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rig            # noqa: E402

HIMA_DONORS = ["hi-bit-shoujo", "micro-hima", "sprite-shoujo", "rowena-rig", "twintail-hima"]


def stripe_layer(top=20, bottom=39, left=30, right=40, role="hair_mid"):
    g = rig.blank()
    for r in range(top, bottom + 1):
        for c in range(left, right + 1):
            g[r][c] = role
    return g


def pixels(g):
    return {(r, c) for r in range(rig.ROWS) for c in range(rig.COLS) if g[r][c] is not None}


def synthetic_tiers(roles=("hair_mid",)):
    """One striped frame per tier, repeated to the spec's frame counts."""
    g = rig.blank()
    for i, role in enumerate(roles):
        for r in range(10 + i, 12 + i):
            for c in range(10, 20):
                g[r][c] = role
    return {t: [g] * n for t, n in rig.FRAMES.items()}


# ---------------------------------------------------------------- Task 1

class RoleMapTests(unittest.TestCase):
    def test_round_trip_keeps_every_pixel_colour_in_every_donor_frame(self):
        """Every donor pixel gets a role whose colour is the donor's own, and no role needs two colours."""
        for sid in HIMA_DONORS:
            sprite = rig.load_source(sid)
            palette, cmap = sprite["palette"], sprite["charMap"]
            for tier, frames in sprite["tiers"].items():
                for i, frame in enumerate(frames):
                    colours = rig.donor_colours(sprite, tier, i)      # raises ValueError if one role would need two colours
                    rm = rig.role_map(frame)
                    wrong = [(r, c, ch) for r, row in enumerate(frame) for c, ch in enumerate(row)
                             if (rm[r][c] is None) != (ch == ".") or (ch != "." and colours[rm[r][c]] != palette[cmap[ch]])]
                    self.assertEqual(wrong, [], f"{sid}/{tier}[{i}]")

    def test_anchor_pixels_get_the_expected_roles(self):
        """Known pixels of hi-bit-shoujo bored[0]: eyes, brow, blush, mouth, dress, socks, shoes, hair, outline, strand ink."""
        rm = rig.role_map(rig.load_source("hi-bit-shoujo")["tiers"]["bored"][0])
        expected = {(33, 25): "eye_white", (33, 26): "iris_hi", (33, 28): "iris_lo", (34, 28): "pupil", (31, 26): "brow",
                    (37, 25): "blush", (39, 33): "mouth", (41, 30): "dress_trim", (43, 30): "ribbon_light", (59, 28): "skin",
                    (62, 29): "sock", (64, 29): "shoe", (20, 18): "hair_deep", (16, 19): "outline", (32, 18): "hair_ink",
                    (51, 21): "hair_ink"}
        self.assertEqual({k: rm[r][c] for k, (r, c) in zip(expected, expected)}, expected)


class PackingTests(unittest.TestCase):
    def test_roles_sharing_a_colour_share_a_slot_in_role_order(self):
        tiers = synthetic_tiers(("skin", "hair_mid", "outline", "blush"))
        sprite = rig.to_sprite("t", "T", tiers, {"skin": "#FADBCF", "hair_mid": "#AAAAAA", "outline": "#000000", "blush": "#FADBCF"})
        self.assertEqual(sprite["palette"], ["#000000", "#AAAAAA", "#FADBCF"])   # outline, hair_mid, skin(+blush)
        self.assertEqual(sprite["charMap"], {"A": 0, "B": 1, "C": 2})
        self.assertEqual(sprite["tiers"]["cruise"][0][10][10:20], "CCCCCCCCCC")

    def test_more_than_sixteen_colours_raises(self):
        roles = tuple(f"r{i}" for i in range(17))
        colours = {f"r{i}": f"#{i:02X}{i:02X}{i:02X}" for i in range(17)}
        with self.assertRaises(ValueError):
            rig.to_sprite("t", "T", synthetic_tiers(roles), colours)

    def test_missing_colour_raises(self):
        with self.assertRaises(ValueError):
            rig.to_sprite("t", "T", synthetic_tiers(("skin",)), {})


class ValidateTests(unittest.TestCase):
    def setUp(self):
        self.sprite = rig.to_sprite("tiny", "Tiny", synthetic_tiers(("skin", "outline")), {"skin": "#FADBCF", "outline": "#000000"})

    def test_synthetic_sprite_is_valid(self):
        self.assertEqual(rig.validate(self.sprite), [])

    def test_ragged_frame_fails(self):
        bad = {**self.sprite, "tiers": {**self.sprite["tiers"]}}
        bad["tiers"]["cruise"] = [f[:-1] for f in bad["tiers"]["cruise"]]
        self.assertTrue(any("rows" in e for e in rig.validate(bad)))

    def test_unmapped_character_fails(self):
        bad = {**self.sprite, "tiers": {**self.sprite["tiers"]}}
        first = bad["tiers"]["top"][0]
        bad["tiers"]["top"] = [["?" + first[0][1:]] + first[1:]] + bad["tiers"]["top"][1:]
        self.assertTrue(any("unmapped" in e for e in rig.validate(bad)))

    def test_seventeen_colours_fail(self):
        pal = [f"#{i:02X}0000" for i in range(17)]
        bad = {**self.sprite, "palette": pal, "charMap": {ch: i for i, ch in enumerate("ABCDEFGHIJKLMNOPQ")}}
        self.assertTrue(any("colours" in e for e in rig.validate(bad)))

    def test_missing_tier_and_wrong_frame_count_fail(self):
        bad = {**self.sprite, "tiers": {t: f for t, f in self.sprite["tiers"].items() if t != "top"}}
        self.assertTrue(any("top" in e for e in rig.validate(bad)))
        short = {**self.sprite, "tiers": {**self.sprite["tiers"], "cruise": self.sprite["tiers"]["cruise"][:2]}}
        self.assertTrue(any("expected 8" in e for e in rig.validate(short)))
        extra = {**self.sprite, "tiers": {**self.sprite["tiers"], "sleep": self.sprite["tiers"]["cruise"]}}
        self.assertTrue(any("unknown tier 'sleep'" in e for e in rig.validate(extra)))

    def test_only_cruise_and_top_are_built_eight_frames_each(self):
        self.assertEqual(rig.TIERS, ["cruise", "top"])
        self.assertEqual(rig.FRAMES, {"cruise": 8, "top": 8})

    def test_dumps_is_one_row_per_line(self):
        text = rig.dumps(self.sprite)
        self.assertTrue(text.endswith("}\n"))
        self.assertIn('\n    "' + self.sprite["tiers"]["cruise"][0][0] + '",\n', text)

# ---------------------------------------------------------------- Task 2

class BendTests(unittest.TestCase):
    def test_zero_amplitude_is_identity(self):
        layer = stripe_layer()
        for t in range(6):
            self.assertEqual(rig.bend(layer, 0, 0, t, 6, root=20), layer)

    def test_root_never_moves_and_the_tip_stays_within_lean_and_amplitude(self):
        layer = stripe_layer(top=20, bottom=39, left=50, right=60)          # right of CENTRE: slides whole
        for t in range(6):
            out = rig.bend(layer, 4, 2, t, 6, root=20)
            self.assertEqual(out[20], layer[20])
            first = min(c for c in range(rig.COLS) if out[39][c] is not None)
            self.assertGreaterEqual(first, 50 - 6)
            self.assertLessEqual(first, 50 - 2)
            self.assertEqual(sum(v is not None for v in out[39]), 11)      # a sliding row keeps its width

    def test_adjacent_rows_never_differ_by_more_than_one_pixel(self):
        layer = stripe_layer(top=12, bottom=57, left=50, right=60)
        for t in range(6):
            out = rig.bend(layer, 4, 2, t, 6, root=12)
            firsts = [min(c for c in range(rig.COLS) if out[r][c] is not None) for r in range(12, 58)]
            self.assertLessEqual(max(abs(a - b) for a, b in zip(firsts, firsts[1:])), 1)

    def test_body_side_lock_keeps_its_inner_edge_and_stretches(self):
        layer = stripe_layer(top=20, bottom=39, left=15, right=25)          # left of CENTRE
        for r in range(20, 40):
            layer[r][15] = "outline"
            layer[r][25] = "outline"
        for t in range(6):
            out = rig.bend(layer, 4, 2, t, 6, root=20)
            self.assertEqual(out[39][25], "outline")                          # inner edge fixed
            self.assertIsNone(out[39][26])
            first = min(c for c in range(rig.COLS) if out[39][c] is not None)
            self.assertEqual(out[39][first], "outline")                       # the outline leads the stretched lock
            self.assertTrue(all(out[39][c] is not None for c in range(first, 26)))   # no gap inside it
        free = rig.bend(layer, 4, 2, 3, 6, root=20, stretch=False)
        self.assertEqual(sum(v is not None for v in free[39]), 11)           # a free lock slides instead

    def test_reverse_direction_moves_the_top(self):
        layer = stripe_layer(top=3, bottom=12, left=50, right=60)
        out = rig.bend(layer, 4, 2, 3, 6, root=12, bottom=3)
        self.assertEqual(out[12], layer[12])
        self.assertLess(min(c for c in range(rig.COLS) if out[3][c] is not None), 50)

    def test_loop_is_seamless(self):
        layer = stripe_layer(top=12, bottom=57, left=50, right=60)
        self.assertEqual(rig.bend(layer, 4, 2, 0, 6, root=12), rig.bend(layer, 4, 2, 6, 6, root=12))


class WagTests(unittest.TestCase):
    def test_root_column_never_moves_and_no_pixel_leaves(self):
        layer = stripe_layer(top=45, bottom=50, left=48, right=60)
        for t in range(6):
            out = rig.wag(layer, 3, t, 6)
            self.assertEqual([out[r][48] for r in range(rig.ROWS)], [layer[r][48] for r in range(rig.ROWS)])
            self.assertEqual(len(pixels(out)), len(pixels(layer)))


class NodTests(unittest.TestCase):
    def test_head_and_front_parts_nod_while_torso_and_back_parts_stay(self):
        body = rig.blank()
        body[30][33] = "skin"                                                # head
        body[50][33] = "dress_white"                                         # torso
        lock = stripe_layer(top=20, bottom=39, left=50, right=52)
        prop = stripe_layer(top=45, bottom=48, left=55, right=58)
        recipe = rig.Recipe("n", "N", {}, body, front=[rig.Part(lock, "rigid")], back=[rig.Part(prop, "rigid")], face=False)
        still, nodded = rig.build_frame(recipe, "cruise", 0), rig.build_frame(recipe, "cruise", 4)
        self.assertEqual(rig.NOD["cruise"][4], 1)
        self.assertEqual(still[30][33], "skin"); self.assertIsNone(nodded[30][33]); self.assertEqual(nodded[31][33], "skin")
        self.assertEqual(nodded[50][33], "dress_white")                     # torso still
        self.assertIsNone(nodded[20][50]); self.assertIsNotNone(nodded[21][50])    # front part nods
        self.assertIsNotNone(nodded[45][55]); self.assertIsNone(nodded[49][55])    # back part stays
        held = rig.Recipe("n", "N", {}, body, front=[rig.Part(lock, "rigid", nod=False)], face=False)
        self.assertIsNotNone(rig.build_frame(held, "cruise", 4)[20][50])     # nod=False keeps a prop with the torso

    def test_top_hops_two_pixels_on_odd_frames_and_refuses_a_recipe_drawn_in_the_top_rows(self):
        body = rig.blank()
        body[30][33] = "skin"
        body[50][33] = "dress_white"
        recipe = rig.Recipe("h", "H", {}, body, face=False)
        self.assertEqual(rig.HOP["top"], [0, 2, 0, 2, 0, 2, 0, 2])
        still, hopped = rig.build_frame(recipe, "top", 0), rig.build_frame(recipe, "top", 1)
        self.assertEqual(still[30][33], "skin"); self.assertEqual(still[50][33], "dress_white")
        self.assertEqual(hopped[28][33], "skin"); self.assertEqual(hopped[48][33], "dress_white")   # the whole frame lifts
        self.assertIsNone(hopped[30][33]); self.assertIsNone(hopped[50][33])
        self.assertEqual(rig.build_frame(recipe, "cruise", 1)[30][33], "skin")                    # cruise never hops
        hat = rig.blank(); hat[1][33] = "outline"
        with self.assertRaises(ValueError):
            rig.build_frame(rig.Recipe("h", "H", {}, body, front=[rig.Part(hat, "rigid")], face=False), "top", 1)

    def test_face_check_follows_the_nod(self):
        recipe = rig.Recipe("f", "F", {}, rig.body_base())
        tiers = rig.build_tiers(recipe)
        self.assertEqual(rig.face_errors("f", tiers), [])
        eyes_row = min(r for (r, c) in rig.FACES["open"])
        self.assertNotEqual(tiers["cruise"][0][eyes_row], tiers["cruise"][4][eyes_row])   # the eyes moved down a row
        self.assertEqual(rig.face_errors("f", {"top": tiers["top"]}), [])                     # the check follows the hop too


class BodyAndFaceTests(unittest.TestCase):
    def test_body_base_has_no_hair_and_no_holes_in_the_dress(self):
        body = rig.body_base()
        self.assertFalse(any(v is not None and v.startswith("hair") for row in body for v in row))
        for r in range(41, 59):
            cols = [c for c in range(rig.COLS) if body[r][c] in rig.BODY_ROLES | {"outline", "ink"}]
            self.assertTrue(all(body[r][c] is not None for c in range(cols[0], cols[-1] + 1)), f"row {r}")
        for r in range(59, 62):                                                   # the gap between the legs stays open
            self.assertTrue(any(body[r][c] is None for c in range(30, 38)), f"row {r} legs are bridged")

    def test_templates_have_no_hair_and_the_mouth_is_the_smile(self):
        for name, template in rig.FACES.items():
            self.assertFalse(any(v.startswith("hair") for v in template.values()), name)
        self.assertEqual({v for v in rig.MOUTH.values()}, {"mouth", "skin"})
        self.assertEqual(rig.MOUTH[(38, 31)], "mouth")
        self.assertEqual(rig.MOUTH[(39, 33)], "mouth")

    def test_old_open_mouth_is_rejected(self):
        old = rig.role_map(rig.load_source("mage")["tiers"]["fast"][0])
        errs = rig.face_errors("mage", {"fast": [old]})
        self.assertTrue(any("mouth is not the smile" in e for e in errs), errs)

    def test_bare_recipe_builds_smiling_frames(self):
        recipe = rig.Recipe("bare", "Bare", {}, rig.paste(rig.skull(), rig.body_base()))
        tiers = rig.build_tiers(recipe)
        self.assertEqual({t: len(f) for t, f in tiers.items()}, rig.FRAMES)
        self.assertEqual(rig.face_errors("bare", tiers), [])
        self.assertNotEqual(tiers["cruise"][3][33][25:40], tiers["cruise"][0][33][25:40])   # the blink frame
        self.assertEqual(tiers["top"][3][31][25:40], tiers["top"][0][33][25:40])              # the alert never blinks (row 31: hopped)


if __name__ == "__main__":
    unittest.main()
