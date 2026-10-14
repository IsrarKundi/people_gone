"""
Shadow growth v1 — synthetic-scene tests (Phase C).

Pure numpy/cv2: no models are loaded. Scenes are toy versions of
the Phase C investigation's cases
(docs/architecture/phase-c-investigation.md) at REPRESENTATIVE
scale: the estimator's locally-dark pools use an image-width-
relative blur kernel, so the scenes are built at 2400x1800 with
360px-tall people — the regime the algorithm was measured in —
rather than at icon scale, where the pools degenerate.

  clear cast shadows     -> estimator finds the direction, growth
                            covers the removed person's streak well
                            beyond the legacy floor
  no shadows             -> estimator stays quiet and v1 output is
                            byte-identical to the legacy floor
  keeper beside removed  -> the keeper's own shadow streak is inside
                            the protected set: growth never enters it
  huge dark region       -> the 3x area cap binds (runaway valve)
  unknown shadow_mode    -> ValueError (explicit path, no fallback)

Run:  cd modal-deploy/server && python -m unittest discover -s tests -t .
"""

import unittest

import cv2
import numpy as np

from worker.mask_prep import (
    dilate_mask,
    expand_shadows,
    fill_mask_holes,
    prepare_individual_removal_masks,
)
from worker.shadow_growth import (
    MAX_ADD_AREA_FRAC,
    collect_direction_samples,
    estimation_pool,
    photo_direction,
    prepare_masks_v1,
)

H, W = 1800, 2400
GROUND = (214, 196, 176)   # bright warm ground: not in any dark pool
STREAK = (58, 52, 48)      # cast shadow: dark, low saturation


def blank_image():
    img = np.zeros((H, W, 3), dtype=np.uint8)
    img[:, :] = GROUND
    return img


def person_mask(box):
    m = np.zeros((H, W), dtype=np.uint8)
    m[box[1]:box[3], box[0]:box[2]] = 255
    return m


def draw_streak(img, p_from, p_to, width=46):
    """Soft-edged streak. The edge softness is small next to the
    streak's width (as in real photos, where the locally-dark pools
    key on the shadow being narrower than the neighbourhood blur).
    Drawn as a white line on an alpha layer, lightly blurred, then
    blended toward the shadow colour."""
    alpha_layer = np.zeros((H, W), dtype=np.uint8)
    cv2.line(alpha_layer, p_from, p_to, 255, width)
    alpha_layer = cv2.GaussianBlur(alpha_layer, (11, 11), 0)
    alpha = (alpha_layer.astype(np.float32) / 255.0)[:, :, None]
    streak_colour = np.array(STREAK, dtype=np.float32).reshape(1, 1, 3)
    blended = img.astype(np.float32) * (1 - alpha) + streak_colour * alpha
    img[:, :] = np.clip(blended, 0, 255).astype(np.uint8)


def streak_core(img, p_from, p_to, width=70):
    """The dark core of a drawn streak: pixels under the (wide) line
    whose composited V is shadow-dark."""
    wide = np.zeros((H, W), dtype=np.uint8)
    cv2.line(wide, p_from, p_to, 255, width)
    v = cv2.cvtColor(img, cv2.COLOR_RGB2HSV)[:, :, 2]
    return (wide > 0) & (v < 150)


def union_of(prepped):
    out = np.zeros((H, W), dtype=bool)
    for item in prepped:
        out |= item["mask"] > 0
    return out


class TestShadowV1(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Removed person on the left, keeper on the right; BOTH cast
        # long streaks down-right (sun up-left). Feet: y=960.
        cls.img = blank_image()
        cls.p_removed = {"id": 0, "box": [300, 600, 420, 960]}
        cls.p_keeper = {"id": 1, "box": [1290, 600, 1410, 960]}
        cls.m_removed = person_mask(cls.p_removed["box"])
        cls.m_keeper = person_mask(cls.p_keeper["box"])
        draw_streak(cls.img, (360, 955), (900, 1630))
        draw_streak(cls.img, (1350, 955), (1890, 1630))
        cls.removed_streak = streak_core(cls.img, (360, 955), (900, 1630))
        cls.keeper_streak = streak_core(cls.img, (1350, 955), (1890, 1630))
        cls.persons = [cls.p_removed, cls.p_keeper]
        cls.masks = [cls.m_removed, cls.m_keeper]

    def test_estimator_finds_downward_direction(self):
        pool = estimation_pool(self.img)
        samples = collect_direction_samples(
            self.img, self.persons, [m > 0 for m in self.masks], pool
        )
        direction, info = photo_direction(samples)
        self.assertIsNotNone(direction)
        self.assertGreater(direction[1], 0.5)  # clearly downward
        self.assertGreater(direction[0], 0.2)  # and to the right

    def test_growth_covers_streak_beyond_floor(self):
        v1 = prepare_masks_v1(self.img, self.persons, self.masks, {0})
        legacy = prepare_individual_removal_masks(
            self.img, self.persons, self.masks, {0}, shadow_mode="legacy"
        )
        streak_only = self.removed_streak & ~(self.m_removed > 0)
        cov_v1 = (union_of(v1) & streak_only).sum() / streak_only.sum()
        cov_legacy = (union_of(legacy) & streak_only).sum() / streak_only.sum()
        self.assertGreater(cov_v1, 0.5)
        self.assertGreater(cov_v1, cov_legacy + 0.2)

    def test_keeper_shadow_never_grown_into(self):
        v1 = prepare_masks_v1(self.img, self.persons, self.masks, {0})
        grown = union_of(v1)
        keeper_only = self.keeper_streak & ~(self.m_keeper > 0)
        self.assertEqual(int((grown & keeper_only).sum()), 0)
        self.assertEqual(int((grown & (self.m_keeper > 0)).sum()), 0)
        # Keeper is not a removal result.
        self.assertEqual([i["person_id"] for i in v1], [0])

    def test_quiet_scene_v1_equals_legacy(self):
        img = blank_image()  # no streaks at all
        v1 = prepare_masks_v1(img, self.persons, self.masks, {0})
        legacy = prepare_individual_removal_masks(
            img, self.persons, self.masks, {0}, shadow_mode="legacy"
        )
        self.assertEqual(len(v1), len(legacy))
        for a, b in zip(v1, legacy):
            self.assertTrue(np.array_equal(a["mask"], b["mask"]))

    def test_legacy_mode_matches_hand_rolled_floor(self):
        legacy = prepare_individual_removal_masks(
            self.img, self.persons, self.masks, {0}, shadow_mode="legacy"
        )
        filled = fill_mask_holes(self.m_removed)
        bh = self.p_removed["box"][3] - self.p_removed["box"][1]
        dilated = dilate_mask(filled, max(8, int(bh * 0.02)))
        floor = expand_shadows(self.img, dilated, self.p_removed["box"])
        self.assertTrue(np.array_equal(legacy[0]["mask"], floor))

    def test_area_cap_binds_on_dark_flood(self):
        img = blank_image()
        img[990:, :] = STREAK  # whole lower half is "shadow"
        draw_streak(img, (360, 955), (600, 1200))
        v1 = prepare_masks_v1(img, self.persons, self.masks, {0})
        legacy = prepare_individual_removal_masks(
            img, self.persons, self.masks, {0}, shadow_mode="legacy"
        )
        added = union_of(v1) & ~union_of(legacy)
        cap = int(MAX_ADD_AREA_FRAC * int((self.m_removed > 0).sum()))
        self.assertLessEqual(int(added.sum()), cap)

    def test_unknown_shadow_mode_raises(self):
        with self.assertRaises(ValueError):
            prepare_individual_removal_masks(
                self.img, self.persons, self.masks, {0},
                shadow_mode="sometimes",
            )


if __name__ == "__main__":
    unittest.main()
