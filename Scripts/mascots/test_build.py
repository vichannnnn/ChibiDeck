#!/usr/bin/env python3
"""Tests for the build.py CLI (spec 2026-09-08 §7): `check` reports, never crashes."""
import contextlib
import io
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build          # noqa: E402
import characters     # noqa: E402


class CheckTests(unittest.TestCase):
    def test_check_lists_a_recipe_that_raises_anything_instead_of_crashing(self):
        def broken():
            raise KeyError("dress_trim")
        out = io.StringIO()
        with mock.patch.dict(characters.RECIPES, {"broken": broken}), contextlib.redirect_stdout(out):
            code = build.cmd_check()
        self.assertEqual(code, 1)
        self.assertIn("broken: KeyError: 'dress_trim'", out.getvalue())


if __name__ == "__main__":
    unittest.main()
