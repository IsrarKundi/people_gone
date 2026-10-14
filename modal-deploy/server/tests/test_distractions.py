"""
Distractions behaviour — Phase B (removal-expansion-plan §4).

Two layers, mirroring test_pipeline_belongings.py:
  1. Pure rules in worker/distractions.py: per-category thresholds,
     cross-class/source dedupe, mask-level OmDet suppression,
     protected-set clipping.
  2. Pipeline behaviour with deterministic fakes: /detect shape,
     an included distraction removed with the keeper's pixels
     clipped out of its mask, a kept distraction untouched, unknown
     ids ignored.

The calibration evidence behind the shipped category set lives in
docs/architecture/phase-b-calibration.md.

Run:  cd modal-deploy/server && python -m unittest discover -s tests -t .
"""

import unittest

import numpy as np

from worker.distractions import (
    DISTRACTION_CATEGORIES,
    DISTRACTION_ID_BASE,
    build_distraction_candidates,
    clip_mask,
    dedupe_distractions,
    filter_by_threshold,
    mask_fraction_inside,
    prepare_distraction_mask,
    suppress_omdet_duplicates,
)
from worker.ghost_check import check_for_distraction_residuals
from worker.pipeline import PeopleGonePipeline, PipelineConfig

H, W = 400, 600
FILL = 77
BASE = 180


def mask_of(*rects):
    m = np.zeros((H, W), dtype=np.uint8)
    for x1, y1, x2, y2 in rects:
        m[y1:y2, x1:x2] = 255
    return m


def det(label, score, box):
    return {"label": label, "score": score, "box": box}


class TestThresholdConfig(unittest.TestCase):
    def test_shipped_category_set_is_exact(self):
        # The calibration gate's shipped list. Stop sign and poles
        # are withheld and must NOT appear here.
        self.assertEqual(
            set(DISTRACTION_CATEGORIES),
            {
                "car", "bus", "truck", "motorbike", "bicycle",
                "traffic light", "parking meter", "bench",
                "fire hydrant", "trash bin", "stroller",
            },
        )

    def test_per_category_thresholds_applied(self):
        dets = [
            det("car", 0.44, [0, 0, 10, 10]),
            det("car", 0.45, [20, 20, 30, 30]),
            det("traffic light", 0.64, [40, 40, 50, 50]),
            det("traffic light", 0.65, [60, 60, 70, 70]),
            det("trash bin", 0.64, [80, 80, 90, 90]),
            det("trash bin", 0.70, [100, 100, 110, 110]),
            det("helicopter", 0.99, [120, 120, 130, 130]),
        ]
        kept = filter_by_threshold(dets)
        self.assertEqual(
            [(d["label"], d["score"]) for d in kept],
            [("car", 0.45), ("traffic light", 0.65), ("trash bin", 0.70)],
        )


class TestDedupe(unittest.TestCase):
    def test_cross_class_twin_keeps_highest_score(self):
        # A white car double-fired as "truck" (calibration family):
        # one item, labelled by the higher score.
        dets = [
            det("truck", 0.60, [100, 100, 300, 200]),
            det("car", 0.90, [102, 98, 298, 202]),
        ]
        kept = dedupe_distractions(dets)
        self.assertEqual(len(kept), 1)
        self.assertEqual(kept[0]["label"], "car")

    def test_nested_boxes_dedupe_but_disjoint_survive(self):
        dets = [
            det("bicycle", 0.80, [0, 0, 200, 200]),
            det("bicycle", 0.70, [10, 10, 100, 100]),   # contained
            det("bicycle", 0.60, [300, 300, 400, 400]),  # disjoint
        ]
        kept = dedupe_distractions(dets)
        self.assertEqual([d["score"] for d in kept], [0.80, 0.60])

    def test_build_candidates_merges_sources(self):
        rt = [det("car", 0.90, [0, 0, 100, 100])]
        om = [
            det("trash bin", 0.70, [300, 300, 360, 380]),
            det("stroller", 0.85, [300, 300, 360, 380]),  # same box
            det("stroller", 0.30, [500, 300, 560, 380]),  # below bar
        ]
        cands = build_distraction_candidates(rt, om)
        self.assertEqual(
            [(c["category"], c["source"]) for c in cands],
            [("car", "rtdetr"), ("stroller", "omdet")],
        )
        self.assertTrue(all("id" not in c for c in cands))


class TestMaskRules(unittest.TestCase):
    def test_mask_fraction_inside(self):
        inner = mask_of((10, 10, 50, 50))
        union = mask_of((30, 10, 90, 50))
        self.assertAlmostEqual(mask_fraction_inside(inner, union), 0.5)
        self.assertEqual(mask_fraction_inside(inner, None), 0.0)
        self.assertEqual(mask_fraction_inside(mask_of(), union), 0.0)

    def test_suppress_omdet_duplicate_of_person(self):
        person_mask = mask_of((60, 80, 130, 320))
        bin_mask = mask_of((500, 40, 560, 120))
        cands = [
            {"category": "trash bin", "box": [40, 50, 140, 350],
             "score": 0.90, "source": "omdet"},
            {"category": "trash bin", "box": [500, 40, 560, 120],
             "score": 0.80, "source": "omdet"},
            {"category": "car", "box": [60, 80, 130, 320],
             "score": 0.95, "source": "rtdetr"},
        ]
        masks = [person_mask.copy(), bin_mask, person_mask.copy()]
        kept_c, kept_m = suppress_omdet_duplicates(
            cands, masks, [person_mask]
        )
        # The OmDet bin whose mask IS the person's mask is suppressed;
        # the disjoint bin survives; the RT-DETR car is never
        # suppressed even with an identical mask.
        self.assertEqual(
            [(c["category"], c["source"]) for c in kept_c],
            [("trash bin", "omdet"), ("car", "rtdetr")],
        )
        self.assertEqual(len(kept_m), 2)

    def test_clip_mask_removes_protected_pixels(self):
        mask = mask_of((100, 250, 300, 330))
        protected = mask_of((60, 80, 130, 320))
        clipped = clip_mask(mask, protected)
        overlap = int(((clipped > 0) & (protected > 0)).sum())
        self.assertEqual(overlap, 0)
        self.assertGreater(int((clipped > 0).sum()), 0)

    def test_prepare_distraction_mask_never_enters_protected(self):
        # Mask 5px from a protected block: the 8px dilation WOULD
        # grow into it without the post-dilation clip.
        mask = mask_of((135, 100, 200, 200))
        protected = mask_of((60, 80, 130, 320))
        prepared = prepare_distraction_mask(mask, [135, 100, 200, 200], protected)
        overlap = int(((prepared > 0) & (protected > 0)).sum())
        self.assertEqual(overlap, 0)
        self.assertGreater(int((prepared > 0).sum()), int((mask > 0).sum()))


class _FakeRT:
    def __init__(self, dets):
        self._dets = dets

    def detect_category(self, image_np, category):
        return [dict(d) for d in self._dets]


class _FakeOmDet:
    fallback_used = False

    def __init__(self, dets):
        self._dets = dets
        self.prompts_seen = None

    def detect(self, image_np, prompts=None):
        self.prompts_seen = prompts
        return [dict(d) for d in self._dets]


class TestGhostDistraction(unittest.TestCase):
    def _image(self):
        return np.full((100, 200, 3), BASE, dtype=np.uint8)

    def test_residual_on_original_box_fires(self):
        # Crop covers the whole toy image; residual box sits on the
        # original item box.
        rt = _FakeRT([det("car", 0.80, [60, 20, 110, 60])])
        fired, residuals = check_for_distraction_residuals(
            self._image(), (0, 0, 200, 100), "car", "rtdetr",
            [50, 10, 120, 70], rt, None,
        )
        self.assertTrue(fired)
        self.assertEqual(len(residuals), 1)

    def test_residual_elsewhere_does_not_fire(self):
        rt = _FakeRT([det("car", 0.80, [150, 20, 190, 60])])
        fired, _ = check_for_distraction_residuals(
            self._image(), (0, 0, 200, 100), "car", "rtdetr",
            [50, 10, 120, 70], rt, None,
        )
        self.assertFalse(fired)

    def test_omdet_source_uses_omdet_with_same_prompt(self):
        om = _FakeOmDet([det("trash bin", 0.90, [55, 15, 115, 65])])
        fired, _ = check_for_distraction_residuals(
            self._image(), (0, 0, 200, 100), "trash bin", "omdet",
            [50, 10, 120, 70], _FakeRT([]), om,
        )
        self.assertTrue(fired)
        self.assertEqual(om.prompts_seen, ["trash bin"])


# --- Pipeline-level fakes -------------------------------------------------
# World: P0 keeper; a car overlapping the keeper's mask; an OmDet bin
# standing alone; an OmDet bin whose SAM mask equals the keeper's
# (the parking-meter failure family — must be suppressed).

PERSONS = [
    {"id": 0, "box": [40, 50, 140, 350], "score": 0.95, "label": "person"},
]
RT_DISTRACTIONS = [
    {"box": [100, 250, 300, 330], "score": 0.90, "label": "car"},
]
OMDET_DETECTIONS = [
    {"box": [40, 50, 140, 350], "score": 0.90, "label": "trash bin"},
    {"box": [500, 40, 560, 120], "score": 0.80, "label": "trash bin"},
]
MASKS_BY_BOX = {
    (40, 50, 140, 350): mask_of((60, 80, 130, 320)),      # person + bin-twin
    (100, 250, 300, 330): mask_of((100, 250, 300, 330)),  # car
    (500, 40, 560, 120): mask_of((500, 40, 560, 120)),    # lone bin
}


class FakeDetector:
    fallback_used = False

    def __init__(self):
        self._served = False

    def _full_frame(self, image_np):
        return image_np.shape[:2] == (H, W) and not self._served

    def detect_persons(self, image_np):
        if not self._full_frame(image_np):
            return []
        self._served = True
        return [dict(p) for p in PERSONS]

    def detect_belongings(self, image_np):
        return []

    def detect_distractions(self, image_np):
        if image_np.shape[:2] != (H, W):
            return []
        return [dict(d) for d in RT_DISTRACTIONS]

    def detect_category(self, image_np, category):
        return []


class FakeSegmentor:
    fallback_used = False

    def segment_boxes(self, image_np, boxes):
        return [MASKS_BY_BOX[tuple(b["box"])] for b in boxes]


class FakeInpainter:
    fallback_used = False

    def inpaint_crop(self, image_crop, mask_crop):
        return np.full(image_crop.shape, FILL, dtype=np.uint8)


class FakeOmDet:
    fallback_used = False

    def detect(self, image_np, prompts=None):
        if image_np.shape[:2] != (H, W):
            return []
        return [dict(d) for d in OMDET_DETECTIONS]


def make_pipeline():
    pipe = PeopleGonePipeline.__new__(PeopleGonePipeline)
    pipe.config = PipelineConfig()  # omdet enabled; fake injected below
    pipe.detector = FakeDetector()
    pipe.segmentor = FakeSegmentor()
    pipe.inpainter = FakeInpainter()
    pipe._omdet_detector = FakeOmDet()
    return pipe


def photo():
    return np.full((H, W, 3), BASE, dtype=np.uint8)


def run_capturing(pipe, **kwargs):
    captured = []
    original_encode = pipe._encode_jpeg

    def capturing_encode(pil_img):
        captured.append(np.array(pil_img))
        return original_encode(pil_img)

    pipe._encode_jpeg = capturing_encode
    _, meta = pipe.process(photo(), **kwargs)
    assert captured, "pipeline never reached the delivery encode"
    return meta, captured[-1]


class TestPipelineDistractions(unittest.TestCase):
    def test_detect_shape_and_mask_suppression(self):
        pipe = make_pipeline()
        res = pipe.detect(photo())
        distractions = res["distractions"]
        # The bin twin of the keeper is suppressed at mask level;
        # car + lone bin survive, ids in the distraction range.
        self.assertEqual(
            [(d["id"], d["category"]) for d in distractions],
            [(DISTRACTION_ID_BASE, "car"), (DISTRACTION_ID_BASE + 1, "trash bin")],
        )
        for d in distractions:
            self.assertEqual(d["kind"], "distraction")
            self.assertEqual(len(d["box"]), 4)
            self.assertGreater(d["score"], 0.0)

    def test_included_distraction_removed_keeper_clipped(self):
        pipe = make_pipeline()
        # The hard rule itself, at the unit level: the distraction
        # unit's mask contains ZERO keeper pixels.
        analysis = pipe._analyse(photo(), keep=[0])
        units, _, _, removed_ids = pipe._build_removal_units(
            photo(), analysis, {DISTRACTION_ID_BASE}, set()
        )
        self.assertEqual(removed_ids, [DISTRACTION_ID_BASE])
        d_unit = [u for u in units if u["kind"] == "distraction"][0]
        keeper_mask = MASKS_BY_BOX[(40, 50, 140, 350)] > 0
        self.assertEqual(
            int(((d_unit["mask"] > 0) & keeper_mask).sum()), 0,
            "distraction mask contains keeper pixels",
        )

        meta, composited = run_capturing(
            pipe, keep=[0], remove_item_ids=[DISTRACTION_ID_BASE]
        )
        self.assertEqual(meta["distractions_removed"], 1)
        self.assertEqual(
            meta["distractions_removed_ids"], [DISTRACTION_ID_BASE]
        )
        # Car centre (outside the keeper) is filled...
        self.assertEqual(int(composited[290, 200, 0]), FILL)
        # ...and the keeper's pixels inside the car's box survive:
        # (115, 285) is inside BOTH the car mask and the keeper mask.
        self.assertEqual(int(composited[285, 115, 0]), BASE)
        # Pixel-exactness follows the project's §5 standard: outside
        # the removal mask grown by the feather/retry margin (8px),
        # keeper pixels are identical. (The composite feather softens
        # a few edge pixels for EVERY unit kind — persons included —
        # which is why §5 defines the margin.)
        from worker.mask_prep import dilate_mask

        allowed = dilate_mask(d_unit["mask"], 8) > 0
        deep_keeper = keeper_mask & ~allowed
        self.assertTrue(
            np.all(composited[deep_keeper] == BASE),
            "keeper pixels changed outside the §5 margin",
        )

    def test_kept_distraction_untouched(self):
        pipe = make_pipeline()
        meta, composited = run_capturing(pipe, keep=[0])
        self.assertEqual(meta["distractions_removed"], 0)
        self.assertTrue(np.all(composited == BASE))

    def test_unknown_distraction_id_ignored(self):
        pipe = make_pipeline()
        meta, composited = run_capturing(
            pipe, keep=[0], remove_item_ids=[DISTRACTION_ID_BASE + 99]
        )
        self.assertEqual(meta["distractions_removed"], 0)
        self.assertTrue(np.all(composited == BASE))


if __name__ == "__main__":
    unittest.main()
