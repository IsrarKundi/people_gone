"""
Keeper protection — overlap fix (2026-10-20).

Synthetic reproduction of the owner's photo failure: a removed
person stands behind the keeper; the keeper has a thin structure
(an 8px-wide "finger") hanging in front of the removed person's
body, inside their bounding box. Before the fix, the removal mask
claimed the finger (SAM overlap), hole filling sealed it in, and
dilation + feather finished it — the delivered photo lost the
fingers while the old pixel-diff acceptance still passed (it
measured keeper regions drawn by the same masks).

These tests pin the three layers of the fix:
  1. keeper_guard_mask geometry (keeper + KEEPER_GUARD_PX ring).
  2. Mask prep (BOTH the production v1 path and legacy): the
     prepared removal mask never enters keeper + guard, and still
     covers the removed person's own area (protection must not gut
     the removal).
  3. The pipeline safety lock: keeper pixels in the final array
     are the original pixels, unconditionally.

Pure numpy/cv2, no models. Run:
  cd modal-deploy/server && python -m unittest discover -s tests -t .
"""

import unittest

import numpy as np

from worker.mask_prep import (
    KEEPER_GUARD_PX,
    keeper_guard_mask,
    prepare_individual_removal_masks,
)
from worker.pipeline import PeopleGonePipeline
from worker.shadow_growth import prepare_masks_v1

H, W = 300, 400
GROUND = (214, 196, 176)  # bright: no shadow candidates, no growth

KEEPER_BOX = [90, 100, 160, 280]
REMOVED_BOX = [150, 100, 280, 280]


def blank_image():
    img = np.zeros((H, W, 3), dtype=np.uint8)
    img[:, :] = GROUND
    return img


def keeper_mask():
    """Body at x90-150, plus an 8px-wide, 8px-tall 'finger' strip
    reaching right into the removed person's rectangle."""
    m = np.zeros((H, W), dtype=np.uint8)
    m[100:280, 90:150] = 255
    m[180:188, 150:158] = 255  # the finger
    return m


def removed_mask():
    """The removed person's SAM mask: a solid rectangle that
    already contains the finger's area (SAM claimed it) — the
    exact pre-fix failure input."""
    m = np.zeros((H, W), dtype=np.uint8)
    m[100:280, 150:280] = 255
    return m


def persons():
    return [
        {"id": 0, "box": KEEPER_BOX},
        {"id": 1, "box": REMOVED_BOX},
    ]


def masks():
    return [keeper_mask(), removed_mask()]


class TestKeeperGuardMask(unittest.TestCase):
    def test_guard_covers_keeper_plus_ring_only(self):
        guard = keeper_guard_mask(persons(), masks(), remove_ids={1})
        km = keeper_mask() > 0
        self.assertTrue(guard[km].all(), "guard must cover the keeper")
        self.assertTrue(guard[184, 159], "guard ring must extend past the fingertip")
        self.assertFalse(guard[150, 250], "guard must not reach deep into the removed person")
        self.assertGreater(KEEPER_GUARD_PX, 0)

    def test_guard_empty_when_no_keepers(self):
        guard = keeper_guard_mask(persons(), masks(), remove_ids={0, 1})
        self.assertFalse(guard.any())


class TestPrepNeverEntersKeeper(unittest.TestCase):
    def _assert_protected(self, prepared):
        self.assertEqual(len(prepared), 1)
        final = prepared[0]["mask"] > 0
        guard = keeper_guard_mask(persons(), masks(), remove_ids={1})
        self.assertFalse(
            (final & guard).any(),
            "prepared removal mask must never enter keeper + guard",
        )
        # The finger itself (inside the keeper mask) is the exact
        # pixel block the bug ate.
        self.assertFalse(final[180:188, 150:158].any())
        # Removal still works away from the keeper.
        self.assertTrue(final[150, 250], "removed person's own area must stay in the mask")

    def test_v1_prep_protects_keeper(self):
        prepared = prepare_masks_v1(
            blank_image(), persons(), masks(), remove_ids={1}
        )
        self._assert_protected(prepared)

    def test_legacy_prep_protects_keeper(self):
        prepared = prepare_individual_removal_masks(
            blank_image(), persons(), masks(), remove_ids={1},
            shadow_mode="legacy",
        )
        self._assert_protected(prepared)


class TestKeeperLock(unittest.TestCase):
    def test_lock_restores_keeper_pixels_unconditionally(self):
        rng = np.random.default_rng(7)
        orig = rng.integers(0, 255, (H, W, 3), dtype=np.uint8)
        trashed = np.zeros_like(orig)  # worst case: fill ate everything
        union = keeper_mask() > 0
        out = PeopleGonePipeline._apply_keeper_lock(trashed, orig, union)
        self.assertTrue((out[union] == orig[union]).all())
        self.assertTrue((out[~union] == trashed[~union]).all())

    def test_lock_noop_without_keeper(self):
        orig = np.full((H, W, 3), 99, dtype=np.uint8)
        comp = np.full((H, W, 3), 7, dtype=np.uint8)
        out = PeopleGonePipeline._apply_keeper_lock(comp, orig, None)
        self.assertTrue((out == 7).all())


if __name__ == "__main__":
    unittest.main()
