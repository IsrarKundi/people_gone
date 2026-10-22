"""
Engine routing + bystander guard — the owner's rule (2026-10-23).

Pins:
  1. decide_engine: R<6 -> RORem; overlap AND R<11 -> RORem;
     else MAT. (Thresholds widened by the owner later on
     2026-10-23 — originally R<3 / overlap AND R<8. The wedding
     case — exactly 3 removals — now reaches RORem via the count
     clause.)
  2. removal_touches_keeper geometry against the keeper guard zone
     (mask_prep.keeper_guard_mask — keeper + KEEPER_GUARD_PX).
  3. FallbackInpainter: a RORem failure under "auto" completes the
     job with MAT (and says so in meta); the wrapper sticks to MAT
     for the rest of the job.
  4. Pipeline integration: "auto" meta carries engine_used /
     routing_reason / removal_count / overlap_detected.
  5. BYSTANDER GUARD: a non-removed person's pixels — mask AND the
     guard band around them, where the composite feather bleeds —
     are the original pixels in the delivered composite, even when
     the fill engine repaints its whole crop.

Pure numpy, fake stages (the test_pipeline_belongings harness
pattern). Run:
  cd modal-deploy/server && python -m unittest discover -s tests -t .
"""

import unittest

import numpy as np

from worker.pipeline import PeopleGonePipeline, PipelineConfig
from worker.routing import (
    FallbackInpainter,
    decide_engine,
    removal_touches_keeper,
)

H, W = 400, 600
BASE = 180
MAT_FILL = 77
ROREM_FILL = 99


def mask_of(*rects):
    m = np.zeros((H, W), dtype=np.uint8)
    for x1, y1, x2, y2 in rects:
        m[y1:y2, x1:x2] = 255
    return m


class TestDecideEngine(unittest.TestCase):
    def test_fewer_than_six_removals_is_rorem(self):
        self.assertEqual(decide_engine(1, False), ("rorem", "r<6"))
        self.assertEqual(decide_engine(2, False), ("rorem", "r<6"))
        # Boundary: 5 removals is still the count clause.
        self.assertEqual(decide_engine(5, False), ("rorem", "r<6"))
        # The count clause wins even when there is also overlap.
        self.assertEqual(decide_engine(5, True), ("rorem", "r<6"))

    def test_overlap_clause(self):
        # Boundary: 6 removals reaches RORem only via overlap.
        self.assertEqual(decide_engine(6, True), ("rorem", "overlap+r<11"))
        self.assertEqual(decide_engine(10, True), ("rorem", "overlap+r<11"))

    def test_default_mat(self):
        # Boundary: 6 removals without overlap is MAT.
        self.assertEqual(decide_engine(6, False), ("mat", "default_mat"))
        self.assertEqual(decide_engine(7, False), ("mat", "default_mat"))
        # 11+ removals is MAT even with overlap.
        self.assertEqual(decide_engine(11, True), ("mat", "default_mat"))
        self.assertEqual(decide_engine(13, True), ("mat", "default_mat"))


class TestRemovalTouchesKeeper(unittest.TestCase):
    def _persons(self):
        return [
            {"id": 0, "box": [40, 50, 140, 350]},
            {"id": 1, "box": [300, 50, 400, 350]},
        ]

    def test_overlapping_masks_touch(self):
        keeper = mask_of((60, 80, 130, 320))
        removed = mask_of((120, 80, 200, 320))  # claims keeper pixels
        self.assertTrue(
            removal_touches_keeper(self._persons(), [keeper, removed], {1})
        )

    def test_adjacent_within_guard_band_touches(self):
        keeper = mask_of((60, 80, 130, 320))
        removed = mask_of((131, 80, 200, 320))  # 1px gap < guard band
        self.assertTrue(
            removal_touches_keeper(self._persons(), [keeper, removed], {1})
        )

    def test_distant_masks_do_not_touch(self):
        keeper = mask_of((60, 80, 130, 320))
        removed = mask_of((320, 80, 380, 320))
        self.assertFalse(
            removal_touches_keeper(self._persons(), [keeper, removed], {1})
        )

    def test_no_keeper_no_touch(self):
        keeper = mask_of((60, 80, 130, 320))
        removed = mask_of((120, 80, 200, 320))
        self.assertFalse(
            removal_touches_keeper(self._persons(), [keeper, removed], {0, 1})
        )


class _Fill:
    fallback_used = False

    def __init__(self, value):
        self.value = value
        self.calls = 0

    def inpaint_crop(self, image_crop, mask_crop):
        self.calls += 1
        return np.full(image_crop.shape, self.value, dtype=np.uint8)


class _Boom:
    fallback_used = False

    def __init__(self):
        self.calls = 0

    def inpaint_crop(self, image_crop, mask_crop):
        self.calls += 1
        raise RuntimeError("rorem exploded")


class TestFallbackInpainter(unittest.TestCase):
    def test_success_uses_primary(self):
        primary, fallback = _Fill(ROREM_FILL), _Fill(MAT_FILL)
        w = FallbackInpainter(primary, fallback)
        out = w.inpaint_crop(np.zeros((4, 4, 3), np.uint8),
                             np.full((4, 4), 255, np.uint8))
        self.assertTrue((out == ROREM_FILL).all())
        self.assertFalse(w.fell_back)
        self.assertEqual(fallback.calls, 0)

    def test_failure_completes_with_mat_and_sticks(self):
        primary, fallback = _Boom(), _Fill(MAT_FILL)
        w = FallbackInpainter(primary, fallback)
        out = w.inpaint_crop(np.zeros((4, 4, 3), np.uint8),
                             np.full((4, 4), 255, np.uint8))
        self.assertTrue((out == MAT_FILL).all())
        self.assertTrue(w.fell_back)
        self.assertIn("rorem exploded", w.error)
        # Second crop goes straight to MAT — no retry of the broken leg.
        w.inpaint_crop(np.zeros((4, 4, 3), np.uint8),
                       np.full((4, 4), 255, np.uint8))
        self.assertEqual(primary.calls, 1)
        self.assertEqual(fallback.calls, 2)


# --- pipeline integration -------------------------------------------------

# Keeper P0 mask x60-130; removed P1 mask x135-200 — a 5px gap, so
# NO guard-zone touch (guard reaches x132): overlap_detected=False,
# and routing is decided by the count clause alone.
PERSONS = [
    {"id": 0, "box": [40, 50, 140, 350], "score": 0.95, "label": "person"},
    {"id": 1, "box": [130, 50, 230, 350], "score": 0.90, "label": "person"},
]
MASKS_BY_BOX = {
    (40, 50, 140, 350): mask_of((60, 80, 130, 320)),
    (130, 50, 230, 350): mask_of((135, 80, 200, 320)),
}


class FakeDetector:
    fallback_used = False

    def __init__(self):
        self._served = False

    def detect_persons(self, image_np):
        if image_np.shape[:2] != (H, W) or self._served:
            return []
        self._served = True
        return [dict(p) for p in PERSONS]

    def detect_belongings(self, image_np):
        return []

    def detect_distractions(self, image_np):
        return []


class FakeSegmentor:
    fallback_used = False

    def segment_boxes(self, image_np, boxes):
        return [MASKS_BY_BOX[tuple(b["box"])] for b in boxes]


def make_pipeline(rorem):
    pipe = PeopleGonePipeline.__new__(PeopleGonePipeline)
    pipe.config = PipelineConfig(omdet_enabled=False)
    pipe.detector = FakeDetector()
    pipe.segmentor = FakeSegmentor()
    pipe.inpainter = _Fill(MAT_FILL)
    pipe._omdet_detector = None
    pipe.engine_request = "auto"
    pipe.inpainters = {"mat": _Fill(MAT_FILL), "rorem": rorem}
    pipe.last_routing = {}
    pipe._auto_fallback = None
    return pipe


def run_capturing(pipe, **kwargs):
    captured = []
    original_encode = pipe._encode_jpeg

    def capturing_encode(pil_img):
        captured.append(np.array(pil_img))
        return original_encode(pil_img)

    pipe._encode_jpeg = capturing_encode
    _, meta = pipe.process(
        np.full((H, W, 3), BASE, dtype=np.uint8), **kwargs
    )
    assert captured, "pipeline never reached the delivery encode"
    return meta, captured[-1]


class TestPipelineRouting(unittest.TestCase):
    def test_auto_small_job_routes_rorem(self):
        rorem = _Fill(ROREM_FILL)
        pipe = make_pipeline(rorem)
        meta, out = run_capturing(pipe, keep=[0])
        self.assertEqual(meta["engine_used"], "rorem")
        self.assertEqual(meta["routing_reason"], "r<6")
        self.assertEqual(meta["removal_count"], 1)
        self.assertFalse(meta["overlap_detected"])
        self.assertEqual(int(out[200, 170, 0]), ROREM_FILL)
        self.assertGreater(rorem.calls, 0)

    def test_auto_rorem_failure_falls_back_to_mat(self):
        pipe = make_pipeline(_Boom())
        meta, out = run_capturing(pipe, keep=[0])
        self.assertEqual(meta["engine_used"], "mat")
        self.assertEqual(meta["routing_reason"], "rorem_failed_fallback")
        # The job still completed: the removed person is filled.
        self.assertEqual(int(out[200, 170, 0]), MAT_FILL)

    def test_forced_mat_never_touches_rorem(self):
        rorem = _Fill(ROREM_FILL)
        pipe = make_pipeline(rorem)
        pipe.engine_request = "mat"
        meta, out = run_capturing(pipe, keep=[0])
        self.assertEqual(meta["engine_used"], "mat")
        self.assertEqual(meta["routing_reason"], "forced")
        self.assertEqual(rorem.calls, 0)
        self.assertEqual(int(out[200, 170, 0]), MAT_FILL)


class TestBystanderGuard(unittest.TestCase):
    """The fill engine repaints its whole crop (the FakeInpainter
    fills everything with MAT_FILL); the composite mask keeps that
    out of the keeper — except the feather, which bleeds a few px
    past the mask edge into the guard band. The guard must restore
    keeper mask AND band to the original pixels."""

    def test_keeper_and_guard_band_restored(self):
        pipe = make_pipeline(_Fill(ROREM_FILL))
        pipe.engine_request = "mat"  # guard applies in BOTH modes
        meta, out = run_capturing(pipe, keep=[0])
        self.assertEqual(int(out[200, 100, 0]), BASE)  # keeper body
        self.assertEqual(int(out[200, 131, 0]), BASE)  # guard band (mask ends x130, band to x132)
        self.assertEqual(int(out[200, 170, 0]), MAT_FILL)  # removal filled


if __name__ == "__main__":
    unittest.main()
