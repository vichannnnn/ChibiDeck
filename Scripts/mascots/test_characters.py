#!/usr/bin/env python3
"""Recipe-level tests (spec 2026-09-08 §8): every shipped recipe builds a valid, smiling, deterministic sprite."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rig            # noqa: E402
import characters     # noqa: E402


class RecipeTests(unittest.TestCase):
    def test_every_recipe_builds_a_valid_sprite_with_sixteen_colours_or_fewer(self):
        for sid, recipe in characters.RECIPES.items():
            sprite = rig.build_sprite(recipe())
            self.assertEqual(sprite["id"], sid)
            self.assertEqual(rig.validate(sprite), [], sid)
            self.assertLessEqual(len(sprite["palette"]), 16, sid)
            self.assertEqual({t: len(f) for t, f in sprite["tiers"].items()}, rig.FRAMES, sid)

    def test_building_twice_gives_identical_text(self):
        for sid, recipe in characters.RECIPES.items():
            self.assertEqual(rig.dumps(rig.build_sprite(recipe())), rig.dumps(rig.build_sprite(recipe())), sid)

    def test_tap_order_matches_the_spec(self):
        spec_order = ["mage", "ruby", "miko", "ivory", "aria", "lilac", "iris", "stella", "rosalie"]
        self.assertEqual(list(characters.RECIPES), [i for i in spec_order if i in characters.RECIPES])


if __name__ == "__main__":
    unittest.main()
