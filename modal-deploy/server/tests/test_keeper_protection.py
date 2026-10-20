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


class TestPrepFillsEnclosures(unittest.TestCase):
    """Phase 2 ordering: hole filling runs on the RAW mask first.
    An under-segmented removed person whose SAM mask only outlines
    them (enclosing their own torso) must still be fully removed —
    Phase 1 carved before filling, opened the enclosure along the
    keeper edge, and left a survivor torso on the owner's photo.
    The keeper stays protected by the post-fill carve + final
    subtraction, proven by the finger assertion below."""

    def _scene(self, with_finger):
        keeper = np.zeros((H, W), dtype=np.uint8)
        keeper[100:280, 90:150] = 255
        if with_finger:
            keeper[150:158, 150:164] = 255  # touches the outline
        removed = np.zeros((H, W), dtype=np.uint8)
        removed[90:250, 160:290] = 255
        removed[98:242, 168:282] = 0  # hollow interior: outline only
        persons = [
            {"id": 0, "box": [90, 100, 165, 280]},
            {"id": 1, "box": [150, 80, 300, 260]},
        ]
        return persons, [keeper, removed]

    def _assert_enclosure_filled(self, prepared, with_finger):
        final = prepared[0]["mask"]
        self.assertEqual(final[170, 225], 255, "enclosed interior must be filled and removed")
        if with_finger:
            self.assertFalse(
                final[150:158, 150:164].any(),
                "keeper finger touching the outline must stay out of the mask",
            )

    def test_v1_fills_enclosure(self):
        persons, masks = self._scene(with_finger=True)
        prepared = prepare_masks_v1(blank_image(), persons, masks, remove_ids={1})
        self._assert_enclosure_filled(prepared, with_finger=True)

    def test_legacy_fills_enclosure(self):
        persons, masks = self._scene(with_finger=True)
        prepared = prepare_individual_removal_masks(
            blank_image(), persons, masks, remove_ids={1}, shadow_mode="legacy"
        )
        self._assert_enclosure_filled(prepared, with_finger=True)


class _FakePredictor:
    """Deterministic SAM stand-in: pass 1 returns the box shrunk
    10%; a refinement call (point_coords present) returns it shrunk
    20% — or an empty mask in degenerate mode."""

    def __init__(self, degenerate=False):
        self.calls = []
        self.degenerate = degenerate
        self._shape = None

    def set_image(self, image_np):
        self._shape = image_np.shape[:2]

    def predict(self, box=None, point_coords=None, point_labels=None,
                multimask_output=False):
        h, w = self._shape
        x1, y1, x2, y2 = [float(v) for v in box[0]]
        refining = point_coords is not None
        self.calls.append({
            "box": (x1, y1, x2, y2),
            "refining": refining,
            "points": None if point_coords is None else np.array(point_coords),
        })
        mask = np.zeros((1, h, w), dtype=np.float32)
        if not (refining and self.degenerate):
            f = 0.20 if refining else 0.10
            ix1, iy1 = int(x1 + (x2 - x1) * f / 2), int(y1 + (y2 - y1) * f / 2)
            ix2, iy2 = int(x2 - (x2 - x1) * f / 2), int(y2 - (y2 - y1) * f / 2)
            mask[0, iy1:iy2, ix1:ix2] = 1.0
        return mask, np.array([0.9], dtype=np.float32), None


def _segmentor_with(fake):
    from worker.segmentor import SamSegmentor

    seg = SamSegmentor()
    seg._predictor = fake
    seg._initialized = True  # skip real model load
    return seg


class TestNegativePointRefinement(unittest.TestCase):
    def _boxes(self):
        return [
            {"id": 0, "box": [50, 50, 150, 250]},    # overlaps 1
            {"id": 1, "box": [120, 50, 220, 250]},   # overlaps 0
            {"id": 2, "box": [280, 50, 380, 250]},   # overlaps nobody; same size as box 0
        ]

    def test_refines_only_overlapped_boxes_with_foreign_points(self):
        fake = _FakePredictor()
        seg = _segmentor_with(fake)
        img = np.zeros((300, 400, 3), dtype=np.uint8)
        masks = seg.segment_boxes(img, self._boxes())
        refine_calls = [c for c in fake.calls if c["refining"]]
        refined_boxes = {c["box"] for c in refine_calls}
        self.assertEqual(refined_boxes, {(50.0, 50.0, 150.0, 250.0), (120.0, 50.0, 220.0, 250.0)})
        # Negative points for box A must sit inside B's territory
        # (x > 120) and inside A's box (x < 150); labels all zero is
        # asserted by construction in the segmentor call contract.
        for c in refine_calls:
            pts = c["points"]
            self.assertGreaterEqual(len(pts), 2)
            if c["box"][0] == 50.0:
                self.assertTrue((pts[:, 0] > 120).all() and (pts[:, 0] < 150).all())
        # Refined mask (20% shrink) adopted for A: smaller than C's
        # pass-1 mask (10% shrink, same box size class).
        self.assertEqual(len(masks), 3)
        self.assertLess(int((masks[0] > 0).sum()), int((masks[2] > 0).sum()))

    def test_degenerate_refinement_keeps_pass1(self):
        fake = _FakePredictor(degenerate=True)
        seg = _segmentor_with(fake)
        img = np.zeros((300, 400, 3), dtype=np.uint8)
        masks = seg.segment_boxes(img, self._boxes())
        # Empty refined mask rejected: A keeps its pass-1 area, which
        # equals C's pass-1 area (identical box dimensions).
        self.assertEqual(int((masks[0] > 0).sum()), int((masks[2] > 0).sum()))


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
