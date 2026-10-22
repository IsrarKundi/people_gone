"""Person-veto tests for the racing inpainter (Phase E, product law:
a fill containing a newly invented PERSON is an automatic reject).

racing_inpainter.py lives at modal-deploy/ root (it is baked into the
worker image next to modal_app.py), so this test puts that directory
on sys.path. The detector and both inpainters are fakes: MAT fills the
mask dark, PowerPaint fills it bright, and the fake detector scripts
its detections off the fill colour it finds — no models are loaded.
"""
import os
import sys
import unittest

import numpy as np

sys.path.insert(
    0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
)

from racing_inpainter import RacingInpainter  # noqa: E402

MAT_COLOUR = (30, 30, 30)
PP_COLOUR = (220, 220, 220)

# Detections in crop coordinates (400x400 crop, mask = 100..300 square).
INSIDE = {"box": [120, 120, 280, 280], "score": 0.45, "label": 0}   # fully in the fill
CONTEXT = {"box": [0, 0, 80, 80], "score": 0.5, "label": 0}          # real person, outside the fill
STRADDLE = {"box": [280, 100, 400, 300], "score": 0.9, "label": 0}  # 17% covered by the fill


class FakeInpainter:
    def __init__(self, colour):
        self.colour = colour
        self.fallback_used = False
        self.calls = 0

    def inpaint_crop(self, image_crop, mask_crop):
        self.calls += 1
        out = np.array(image_crop, copy=True)
        out[mask_crop > 127] = self.colour
        return out


class FakeDetector:
    """Scripts detections per candidate: `script(is_pp)` decides."""

    def __init__(self, script):
        self.script = script

    def detect_persons(self, img):
        is_pp = int(img[200, 200][0]) > 128  # centre of the mask = fill colour
        return [dict(d) for d in self.script(is_pp)]


def make_racing(script):
    mat = FakeInpainter(MAT_COLOUR)
    pp = FakeInpainter(PP_COLOUR)
    racing = RacingInpainter(mat, pp, FakeDetector(script))
    img = np.zeros((400, 400, 3), dtype=np.uint8)
    mask = np.zeros((400, 400), dtype=np.uint8)
    mask[100:300, 100:300] = 255  # 40,000 px, ratio 0.25 -> raced
    return racing, mat, pp, img, mask


class PersonVetoTests(unittest.TestCase):
    def test_pp_person_in_fill_is_vetoed(self):
        # PP candidate carries a person INSIDE the fill (score 0.45).
        # Residuals: MAT 0.5, PP 0.95 — the pre-veto rules would have
        # picked PP (0.95 <= bar 1.0 and <= 0.5 + margin 0.5). The veto
        # must override them.
        racing, mat, pp, img, mask = make_racing(
            lambda is_pp: [CONTEXT, INSIDE] if is_pp else [CONTEXT]
        )
        result = racing.inpaint_crop(img, mask)
        rec = racing.records[-1]
        self.assertEqual(rec["winner"], "mat")
        self.assertEqual(rec["win_reason"], "pp_person_veto")
        self.assertEqual(len(rec["pp_person_hits"]), 1)
        self.assertEqual(rec["pp_person_hits"][0]["mask_overlap"], 1.0)
        self.assertEqual(rec["mat_person_hits"], [])
        self.assertEqual(int(result[200, 200][0]), MAT_COLOUR[0])

    def test_context_person_does_not_veto(self):
        # Same real person OUTSIDE the fill in both candidates: nobody
        # is vetoed and the cleaner-scoring PP fill wins as before.
        racing, mat, pp, img, mask = make_racing(lambda is_pp: [CONTEXT])
        result = racing.inpaint_crop(img, mask)
        rec = racing.records[-1]
        self.assertEqual(rec["winner"], "powerpaint")
        self.assertEqual(rec["win_reason"], "pp_clean")
        self.assertEqual(rec["pp_person_hits"], [])
        self.assertEqual(int(result[200, 200][0]), PP_COLOUR[0])

    def test_straddling_detection_does_not_veto(self):
        # A detection mostly OUTSIDE the fill (a keeper straddling the
        # fill edge) is not "a person in the fill" — no veto.
        racing, mat, pp, img, mask = make_racing(
            lambda is_pp: [STRADDLE] if is_pp else [CONTEXT]
        )
        racing.inpaint_crop(img, mask)
        rec = racing.records[-1]
        self.assertEqual(rec["pp_person_hits"], [])
        self.assertEqual(rec["winner"], "powerpaint")

    def test_small_crop_never_races(self):
        racing, mat, pp, img, _mask = make_racing(lambda is_pp: [INSIDE])
        small = np.zeros((400, 400), dtype=np.uint8)
        small[0:50, 0:50] = 255  # 2,500 px — below the race floor
        racing.inpaint_crop(img, small)
        rec = racing.records[-1]
        self.assertFalse(rec["raced"])
        self.assertEqual(rec["winner"], "mat")
        self.assertEqual(pp.calls, 0)


if __name__ == "__main__":
    unittest.main()
