"""
FINAL-COMPOSITE PIXEL-DIFF acceptance test (plan §5, Phase A).

The protected-set guarantee ("keeper pixels are never touched") is
proven at the OUTPUT, not assumed from the mask logic: on a real
photo with a real belongings removal — the owner's Badshahi Mosque
photo, whose messenger bag the investigation attached to removed
person P4 — this test runs the REAL detector + SAM + tiering + mask
prep through the production pipeline and asserts:

  1. Outside the union of removal masks (grown by the maximum
     possible feather + ghost-retry margin), the composited array is
     PIXEL-IDENTICAL to the source array, pre-encode.
  2. The removal actually happened (the union region did change).

The inpainter is a constant-fill stub: what is under test is the
mask/composite discipline of the pipeline, not fill quality (fill
quality is gated by the would-post tests, Requirements §3). Every
other stage is the production code with production weights.

Gated (slow: real models on CPU) — run with:
  PG_RUN_PIXEL_DIFF=1 python -m unittest tests.test_pixel_diff
Photo path override: PG_PIXEL_DIFF_PHOTO=/path/to/photo.jpg
"""

import os
import unittest

os.environ.setdefault(
    "HF_HOME",
    os.path.expanduser("~/workspace/peoplegone/phase0-run/hf-cache"),
)
os.environ.setdefault("HF_HUB_OFFLINE", "1")

import numpy as np

DEFAULT_PHOTO = os.path.expanduser(
    "~/workspace/user/media_library/image/38/"
    "3864b22dfdf3d2052f82d7a2c0db5c8dadd1675b376d557a9c24066c1e26ed18.jpg"
)


@unittest.skipUnless(
    os.environ.get("PG_RUN_PIXEL_DIFF") == "1",
    "slow acceptance test: set PG_RUN_PIXEL_DIFF=1 (real models, CPU)",
)
class TestFinalCompositePixelDiff(unittest.TestCase):
    def test_protected_pixels_identical_outside_removal_union(self):
        from PIL import Image, ImageOps

        from worker.mask_prep import dilate_mask
        from worker.pipeline import PeopleGonePipeline, PipelineConfig

        photo_path = os.environ.get("PG_PIXEL_DIFF_PHOTO", DEFAULT_PHOTO)
        if not os.path.exists(photo_path):
            self.skipTest(f"fixture photo not present: {photo_path}")

        # OmDet disabled: the local test env pins transformers 4.44.2
        # (no OmDet classes) and this case is about belongings. The
        # distraction case below uses an RT-DETR category for the
        # same reason; OmDet-path discipline is covered by unit tests.
        pipe = PeopleGonePipeline(PipelineConfig(omdet_enabled=False))

        class StubInpainter:
            fallback_used = False

            def inpaint_crop(self, image_crop, mask_crop):
                return np.full(image_crop.shape, 200, dtype=np.uint8)

        pipe.inpainter = StubInpainter()

        with open(photo_path, "rb") as f:
            photo_bytes = f.read()

        # The heuristic keeper set is what /detect proposes; confirming
        # it removes everyone else, including the bag's owner.
        detect = pipe.detect(photo_bytes)
        self.assertGreater(detect["persons_detected"], 1)
        keeper_ids = detect["keeper_ids"]
        self.assertTrue(keeper_ids)
        attached = [b for b in detect["belongings"] if b["tier"] == "attached"]
        self.assertTrue(
            attached,
            "fixture must contain an attached belonging (the mosque bag)",
        )

        # Expected removal region, from the production unit builder.
        orig = np.array(ImageOps.exif_transpose(Image.open(photo_path)).convert("RGB"))
        analysis = pipe._analyse(orig, keep=keeper_ids)
        units, removed_item_ids, _, _ = pipe._build_removal_units(
            orig, analysis, set(), set()
        )
        self.assertTrue(units)
        self.assertTrue(removed_item_ids, "the bag must be a removal unit member")
        union = np.zeros(orig.shape[:2], dtype=np.uint8)
        max_margin = 0
        for unit in units:
            union = np.maximum(union, unit["mask"])
            retry_px = max(12, int(unit["height"] * pipe.config.retry_dilation_factor))
            max_margin = max(max_margin, retry_px)
        # Feather (<=6 px, Gaussian support) + ghost-retry re-dilation.
        allowed = dilate_mask(union, max_margin + 8) > 0

        # The real run, capturing the pre-encode composite.
        captured = []
        original_encode = pipe._encode_jpeg

        def capturing_encode(pil_img):
            captured.append(np.array(pil_img))
            return original_encode(pil_img)

        pipe._encode_jpeg = capturing_encode
        _, meta = pipe.process(photo_bytes, keep=keeper_ids)
        self.assertTrue(captured)
        composited = captured[-1]

        self.assertEqual(meta["belongings_removed_ids"], removed_item_ids)
        changed = np.any(composited != orig, axis=2)
        outside = changed & ~allowed
        self.assertEqual(
            int(outside.sum()),
            0,
            "protected pixels changed outside the removal union",
        )
        union_area = int((union > 0).sum())
        changed_in_union = int((changed & (union > 0)).sum())
        self.assertGreater(
            changed_in_union,
            union_area // 2,
            "sanity: the removal region must actually change",
        )


DISTRACTION_PHOTO = os.path.expanduser(
    "~/workspace/peoplegone/phase-b-build/calib_photos/px_bus_yellow.jpg"
)


@unittest.skipUnless(
    os.environ.get("PG_RUN_PIXEL_DIFF") == "1",
    "slow acceptance test: set PG_RUN_PIXEL_DIFF=1 (real models, CPU)",
)
class TestDistractionPixelDiff(unittest.TestCase):
    """Phase B extension of the §5 acceptance test: an included
    distraction (a bus, RT-DETR category) is removed beside keeper
    persons. Asserts (1) the distraction unit's mask contains ZERO
    keeper-mask pixels (protected-set clipping, the hard rule),
    (2) the final composite is pixel-identical outside the removal
    union grown by the retry/feather margin, and (3) the distraction
    region actually changed. Photo override:
    PG_PIXEL_DIFF_DISTRACTION_PHOTO."""

    def test_distraction_removal_respects_protected_set(self):
        from PIL import Image, ImageOps

        from worker.mask_prep import dilate_mask
        from worker.pipeline import PeopleGonePipeline, PipelineConfig

        photo_path = os.environ.get(
            "PG_PIXEL_DIFF_DISTRACTION_PHOTO", DISTRACTION_PHOTO
        )
        if not os.path.exists(photo_path):
            self.skipTest(f"fixture photo not present: {photo_path}")

        pipe = PeopleGonePipeline(PipelineConfig(omdet_enabled=False))

        class StubInpainter:
            fallback_used = False

            def inpaint_crop(self, image_crop, mask_crop):
                return np.full(image_crop.shape, 200, dtype=np.uint8)

        pipe.inpainter = StubInpainter()

        with open(photo_path, "rb") as f:
            photo_bytes = f.read()

        detect = pipe.detect(photo_bytes)
        self.assertTrue(detect["distractions"], "fixture must yield distractions")
        target = detect["distractions"][0]
        keeper_ids = detect["keeper_ids"]
        self.assertTrue(keeper_ids, "fixture must have a keeper person")

        orig = np.array(
            ImageOps.exif_transpose(Image.open(photo_path)).convert("RGB")
        )
        analysis = pipe._analyse(orig, keep=keeper_ids)
        units, _, _, distraction_ids = pipe._build_removal_units(
            orig, analysis, {target["id"]}, set()
        )
        self.assertEqual(distraction_ids, [target["id"]])
        distraction_units = [u for u in units if u["kind"] == "distraction"]
        self.assertEqual(len(distraction_units), 1)
        d_unit = distraction_units[0]

        # (1) Protected-set clipping: zero overlap with keeper masks.
        keeper_union = np.zeros(orig.shape[:2], dtype=np.uint8)
        person_index = {p["id"]: i for i, p in enumerate(analysis["persons"])}
        for pid in keeper_ids:
            keeper_union = np.maximum(
                keeper_union, analysis["person_masks"][person_index[pid]]
            )
        overlap = int(((d_unit["mask"] > 0) & (keeper_union > 0)).sum())
        self.assertEqual(overlap, 0, "distraction mask touches keeper pixels")

        union = np.zeros(orig.shape[:2], dtype=np.uint8)
        max_margin = 0
        for unit in units:
            union = np.maximum(union, unit["mask"])
            retry_px = max(
                12, int(unit["height"] * pipe.config.retry_dilation_factor)
            )
            max_margin = max(max_margin, retry_px)
        allowed = dilate_mask(union, max_margin + 8) > 0

        captured = []
        original_encode = pipe._encode_jpeg

        def capturing_encode(pil_img):
            captured.append(np.array(pil_img))
            return original_encode(pil_img)

        pipe._encode_jpeg = capturing_encode
        _, meta = pipe.process(
            photo_bytes, keep=keeper_ids, remove_item_ids=[target["id"]]
        )
        self.assertTrue(captured)
        composited = captured[-1]

        self.assertEqual(meta["distractions_removed_ids"], [target["id"]])
        self.assertEqual(meta["distractions_removed"], 1)

        # (2) Nothing outside the allowed union changed.
        changed = np.any(composited != orig, axis=2)
        outside = changed & ~allowed
        self.assertEqual(
            int(outside.sum()),
            0,
            "protected pixels changed outside the removal union",
        )
        # (3) The distraction region actually changed.
        d_area = int((d_unit["mask"] > 0).sum())
        changed_in_d = int((changed & (d_unit["mask"] > 0)).sum())
        self.assertGreater(
            changed_in_d, d_area // 2,
            "sanity: the distraction region must actually change",
        )


if __name__ == "__main__":
    unittest.main()
