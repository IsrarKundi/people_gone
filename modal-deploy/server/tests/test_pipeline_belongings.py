"""
Pipeline belongings behaviour — synthetic-stage tests (Phase A, FR-08).

The real detector/segmentor/inpainter are replaced with deterministic
fakes so the PIPELINE logic is what is measured:

  attached belonging is removed together with its owner
  detached belonging is NEVER in a removal mask (its pixels survive)
  ambiguous belonging is removed only when the user includes it
  the keeper's pixels are never touched
  Contract v3 meta (belongings_removed_ids / items_removed /
  belongings_detached_ids) reports exactly what happened

The final-composite pixel-diff acceptance test on a REAL photo with
the REAL models lives in test_pixel_diff.py (plan §5).

Run:  cd modal-deploy/server && python -m unittest discover -s tests -t .
"""

import unittest

import numpy as np

from worker.pipeline import PeopleGonePipeline, PipelineConfig

H, W = 400, 600
FILL = 77
BASE = 180


def mask_of(*rects):
    m = np.zeros((H, W), dtype=np.uint8)
    for x1, y1, x2, y2 in rects:
        m[y1:y2, x1:x2] = 255
    return m


# Geometry (see test_belongings.py for the tiering rules):
#   P0 keeper  box [40,50,140,350],   mask (60,80)-(130,320)
#   P1 removed box [300,50,400,350],  mask (320,80)-(380,320)
#   B0 bag     box [384,150,430,230], mask same -> inside P1's halo
#              (overlap 4x80=320 px >= bar) => ATTACHED to P1
#   B1 case    box [480,280,540,340], mask same -> touches nobody
#              => AMBIGUOUS
PERSONS = [
    {"id": 0, "box": [40, 50, 140, 350], "score": 0.95, "label": "person"},
    {"id": 1, "box": [300, 50, 400, 350], "score": 0.90, "label": "person"},
]
ITEMS = [
    {"id": 0, "box": [384, 150, 430, 230], "score": 0.88, "label": "handbag"},
    {"id": 1, "box": [480, 280, 540, 340], "score": 0.80, "label": "suitcase"},
]
MASKS_BY_BOX = {
    (40, 50, 140, 350): mask_of((60, 80, 130, 320)),
    (300, 50, 400, 350): mask_of((320, 80, 380, 320)),
    (384, 150, 430, 230): mask_of((384, 150, 430, 230)),
    (480, 280, 540, 340): mask_of((480, 280, 540, 340)),
}


class FakeDetector:
    """Answers the analysis pass once; every later call (the ghost
    checks, whose crops can span the whole frame at this toy scale)
    sees the cleaned photo and finds nothing — exactly what the real
    detector reports after a successful clean."""

    fallback_used = False

    def __init__(self):
        self._persons_served = False
        self._items_served = False

    def detect_persons(self, image_np):
        if image_np.shape[:2] != (H, W) or self._persons_served:
            return []
        self._persons_served = True
        return [dict(p) for p in PERSONS]

    def detect_belongings(self, image_np):
        if image_np.shape[:2] != (H, W) or self._items_served:
            return []
        self._items_served = True
        return [dict(i) for i in ITEMS]

    def detect_distractions(self, image_np):
        # Phase B stage exists in the pipeline; this fixture's world
        # contains no distractions.
        return []


class FakeSegmentor:
    fallback_used = False

    def segment_boxes(self, image_np, boxes):
        return [MASKS_BY_BOX[tuple(b["box"])] for b in boxes]


class FakeInpainter:
    fallback_used = False

    def inpaint_crop(self, image_crop, mask_crop):
        return np.full(image_crop.shape, FILL, dtype=np.uint8)


def make_pipeline():
    pipe = PeopleGonePipeline.__new__(PeopleGonePipeline)
    # OmDet disabled: these tests model the RT-DETR world only (the
    # OmDet stage has its own fakes in test_distractions.py).
    pipe.config = PipelineConfig(omdet_enabled=False)
    pipe.detector = FakeDetector()
    pipe.segmentor = FakeSegmentor()
    pipe.inpainter = FakeInpainter()
    pipe._omdet_detector = None
    return pipe


def photo():
    return np.full((H, W, 3), BASE, dtype=np.uint8)


def run_capturing(pipe, **kwargs):
    """Runs process() and returns (meta, composited array PRE-ENCODE).

    Pixel assertions belong on the pre-encode composite (plan §5):
    the delivered JPEG is lossy, so decoding it would measure the
    encoder's ringing, not the pipeline's mask discipline.
    """
    captured = []
    original_encode = pipe._encode_jpeg

    def capturing_encode(pil_img):
        captured.append(np.array(pil_img))
        return original_encode(pil_img)

    pipe._encode_jpeg = capturing_encode
    _, meta = pipe.process(photo(), **kwargs)
    assert captured, "pipeline never reached the delivery encode"
    return meta, captured[-1]


class TestPipelineBelongings(unittest.TestCase):
    def test_detect_returns_v3_belongings(self):
        pipe = make_pipeline()
        res = pipe.detect(photo())
        self.assertEqual(res["contract_version"], 3)
        self.assertEqual(res["persons_detected"], 2)
        by_id = {b["id"]: b for b in res["belongings"]}
        self.assertEqual(by_id[0]["tier"], "attached")
        self.assertEqual(by_id[0]["person_id"], 1)
        self.assertEqual(by_id[0]["detected_class"], "handbag")
        self.assertEqual(by_id[1]["tier"], "ambiguous")
        self.assertIsNone(by_id[1]["person_id"])

    def test_attached_belonging_removed_with_owner(self):
        pipe = make_pipeline()
        meta, out = run_capturing(pipe, keep=[0])
        self.assertEqual(int(out[200, 350, 0]), FILL)  # P1 body gone
        self.assertEqual(int(out[190, 407, 0]), FILL)  # P1's bag gone
        self.assertEqual(int(out[200, 95, 0]), BASE)   # keeper intact
        self.assertEqual(meta["belongings_removed_ids"], [0])
        self.assertEqual(meta["items_removed"], 0)  # attached != itemised
        self.assertEqual(meta["removed_ids"], [1])

    def test_detached_belonging_is_never_masked(self):
        pipe = make_pipeline()
        meta, out = run_capturing(pipe, keep=[0], detached_belonging_ids=[0])
        self.assertEqual(int(out[200, 350, 0]), FILL)  # owner still removed
        self.assertEqual(int(out[190, 407, 0]), BASE)  # bag survives intact
        self.assertEqual(meta["belongings_removed_ids"], [])
        self.assertEqual(meta["belongings_detached_ids"], [0])

    def test_ambiguous_item_removed_only_when_included(self):
        pipe = make_pipeline()
        meta, out = run_capturing(pipe, keep=[0])
        self.assertEqual(int(out[310, 510, 0]), BASE)  # left alone
        self.assertEqual(meta["items_removed"], 0)

        pipe = make_pipeline()
        meta, out = run_capturing(pipe, keep=[0], remove_item_ids=[1])
        self.assertEqual(int(out[310, 510, 0]), FILL)  # user included it
        self.assertEqual(meta["items_removed"], 1)
        self.assertEqual(meta["belongings_removed_ids"], [0, 1])

    def test_keep_everyone_removes_nothing(self):
        pipe = make_pipeline()
        meta, out = run_capturing(pipe, keep=[0, 1])
        self.assertTrue(bool((out == BASE).all()))
        self.assertEqual(meta["belongings_removed_ids"], [])


if __name__ == "__main__":
    unittest.main()
