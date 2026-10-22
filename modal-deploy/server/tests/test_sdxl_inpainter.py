"""Unit tests for the SDXL inpainter's pure logic (Phase E2).

sdxl_inpainter.py lives at modal-deploy/ root (baked into the worker
image next to modal_app.py), so this test puts that directory on
sys.path. No model is loaded: the pipeline is a fake that records its
call kwargs and returns a solid image, and _lazy_init is pre-empted by
marking the instance initialized — the same fake-everything style as
test_racing_veto.py.
"""
import os
import sys
import unittest

import numpy as np
from PIL import Image

sys.path.insert(
    0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
)

from sdxl_inpainter import (  # noqa: E402
    GUIDANCE_SCALE,
    MAX_TOTAL_PX,
    MODEL_ID,
    NEGATIVE_PROMPT,
    PROMPT_POSITIVE,
    SHORT_SIDE_PX,
    STRENGTH,
    XLInpainter,
    target_size,
)


class TargetSizeTests(unittest.TestCase):
    def test_short_side_becomes_1024(self):
        # Wedding-class crop (portrait): short side 985 -> 1024.
        tw, th = target_size(985, 1218)
        self.assertEqual(tw, 1024)
        self.assertEqual(th % 8, 0)
        self.assertGreater(th, tw)

    def test_multiples_of_8_and_minimum(self):
        for w, h in [(333, 777), (100, 100), (64, 2000), (2000, 64)]:
            tw, th = target_size(w, h)
            self.assertEqual(tw % 8, 0)
            self.assertEqual(th % 8, 0)
            self.assertGreaterEqual(tw, 64)
            self.assertGreaterEqual(th, 64)

    def test_pixel_cap_downscales_large_crops(self):
        # Piazza-class crop: 1024-short-side scaling would exceed the cap.
        tw, th = target_size(2000, 1350)
        self.assertLessEqual(tw * th, MAX_TOTAL_PX)
        # Aspect ratio preserved (within the multiple-of-8 rounding).
        self.assertAlmostEqual(tw / th, 2000 / 1350, delta=0.02)

    def test_uncapped_crop_runs_at_native_scale(self):
        # ~1.0-1.23M px wedding crops stay essentially at 1024 short side.
        tw, th = target_size(1024, 1200)
        self.assertEqual((tw, th), (1024, 1200))

    def test_invalid_size_raises(self):
        with self.assertRaises(ValueError):
            target_size(0, 100)


class PromptConstantTests(unittest.TestCase):
    def test_model_id_is_the_diffusers_inpainting_repo(self):
        self.assertEqual(
            MODEL_ID, "diffusers/stable-diffusion-xl-1.0-inpainting-0.1"
        )

    def test_negative_list_matches_phase_e_extended_list(self):
        # The Phase E plain-language guard list, minus PP's P_obj token.
        for term in (
            "person", "people", "man", "woman", "face", "head", "hands",
            "body", "crowd", "text", "letters", "words", "sign", "logo",
            "watermark",
        ):
            self.assertIn(term, NEGATIVE_PROMPT)
        self.assertNotIn("P_obj", NEGATIVE_PROMPT)
        self.assertNotIn("P_ctxt", NEGATIVE_PROMPT)

    def test_positive_prompt_is_generic_background(self):
        self.assertIn("no people", PROMPT_POSITIVE)
        self.assertIn("background", PROMPT_POSITIVE)

    def test_recipe_constants(self):
        self.assertEqual(STRENGTH, 1.0)
        self.assertEqual(GUIDANCE_SCALE, 7.5)
        self.assertEqual(SHORT_SIDE_PX, 1024)
        self.assertEqual(MAX_TOTAL_PX, 1_600_000)


class FakePipe:
    """Records the call, returns a solid image of the requested size."""

    def __init__(self):
        self.kwargs = None

    def __call__(self, **kwargs):
        self.kwargs = kwargs
        img = Image.new("RGB", (kwargs["width"], kwargs["height"]), (10, 20, 30))

        class _Out:
            images = [img]

        return _Out()


class StubbedPipelineTests(unittest.TestCase):
    def _make(self):
        xl = XLInpainter(device="cpu")
        xl._pipe = FakePipe()
        xl._initialized = True  # skip the real lazy load
        return xl

    def test_inpaint_crop_calls_pipe_with_recipe_and_restores_size(self):
        xl = self._make()
        img = np.zeros((500, 700, 3), dtype=np.uint8)
        mask = np.zeros((500, 700), dtype=np.uint8)
        mask[100:300, 100:300] = 255
        out = xl.inpaint_crop(img, mask)
        # Result resized back to the crop size, like the PP leg.
        self.assertEqual(out.shape, (500, 700, 3))
        kw = xl._pipe.kwargs
        self.assertEqual(kw["prompt"], PROMPT_POSITIVE)
        self.assertEqual(kw["negative_prompt"], NEGATIVE_PROMPT)
        self.assertEqual(kw["strength"], STRENGTH)
        self.assertEqual(kw["guidance_scale"], GUIDANCE_SCALE)
        self.assertEqual(kw["num_inference_steps"], 28)  # XL_STEPS default
        tw, th = target_size(700, 500)
        self.assertEqual((kw["width"], kw["height"]), (tw, th))
        self.assertFalse(xl.fallback_used)

    def test_steps_come_from_env(self):
        os.environ["XL_STEPS"] = "12"
        try:
            xl = self._make()
            img = np.zeros((200, 200, 3), dtype=np.uint8)
            mask = np.zeros((200, 200), dtype=np.uint8)
            xl.inpaint_crop(img, mask)
            self.assertEqual(xl._pipe.kwargs["num_inference_steps"], 12)
        finally:
            del os.environ["XL_STEPS"]

    def test_defaults_come_from_env(self):
        xl = XLInpainter()
        self.assertEqual(
            xl.ckpt_dir,
            os.environ.get("SDXL_CKPT_DIR", "/models/sdxl-inpaint"),
        )
        self.assertIsNone(xl.device)  # auto-resolved at lazy load
        self.assertFalse(xl._initialized)


if __name__ == "__main__":
    unittest.main()
