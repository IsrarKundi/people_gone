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
        from worker.pipeline import PeopleGonePipeline

        photo_path = os.environ.get("PG_PIXEL_DIFF_PHOTO", DEFAULT_PHOTO)
        if not os.path.exists(photo_path):
            self.skipTest(f"fixture photo not present: {photo_path}")

        pipe = PeopleGonePipeline()

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
        units, removed_item_ids, _ = pipe._build_removal_units(
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


if __name__ == "__main__":
    unittest.main()
