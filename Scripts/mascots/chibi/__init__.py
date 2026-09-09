"""The chibi roster (2026-09-08): characters designed from the user's reference sheet, one module each.

Every module exposes `recipe() -> rig.Recipe`. Tap order continues after Mage (roster spec §6):
ruby 1 · miko 2 · ivory 3 · aria 4 · lilac 5 · iris 6 · stella 7 · rosalie 8."""
from . import aria, iris, ivory, lilac, miko, rosalie, ruby, stella

ROSTER = (ruby, miko, ivory, aria, lilac, iris, stella, rosalie)
RECIPES = {m.__name__.rsplit(".", 1)[-1]: m.recipe for m in ROSTER}
