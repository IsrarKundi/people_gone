"""
Distractions — PeopleGone Phase B (removal-expansion-plan §4).

Non-person street objects the user can choose to remove (bins, cars,
benches, …). Two detection sources:

- The existing RT-DETR pass (closed COCO vocab) for the classes it
  already finds well: car, bus, truck, motorbike, bicycle,
  traffic light, parking meter, bench, fire hydrant.
- OmDet-Turbo Tiny (Apache-2.0, open vocab) for the two COCO-missing
  prompts that passed the calibration gate: "trash bin", "stroller".

Every category in DISTRACTION_CATEGORIES earned its place in the
Phase B calibration (docs/architecture/phase-b-calibration.md):
measured precision 100% at its threshold on a 30-photo / 321-detection
by-eye test set, in the production simulation (thresholds + dedupe +
suppression). Categories that failed or lacked evidence are NOT in
the dict — poles and street signs are withheld entirely (spike
verdict), and stop sign is withheld on thin/confused evidence
(calibration doc). Adding a category = adding one config line after
it passes the same gate.

Distractions are DEFAULT KEEP in the app (design X3): nothing in this
module removes anything by itself; it only proposes items.
"""

import os
from typing import Any, Dict, List, Optional, Sequence, Tuple

import numpy as np

from .mask_prep import dilate_mask, fill_mask_holes

# The ONE config place for distraction categories (calibration doc has
# the per-category evidence). "motorbike" is this checkpoint's own
# id2label spelling (not canonical COCO "motorcycle").
DISTRACTION_CATEGORIES: Dict[str, Dict[str, Any]] = {
    "car":           {"source": "rtdetr", "threshold": 0.45},
    "bus":           {"source": "rtdetr", "threshold": 0.45},
    "truck":         {"source": "rtdetr", "threshold": 0.55},
    "motorbike":     {"source": "rtdetr", "threshold": 0.55},
    "bicycle":       {"source": "rtdetr", "threshold": 0.45},
    "traffic light": {"source": "rtdetr", "threshold": 0.65},
    "parking meter": {"source": "rtdetr", "threshold": 0.55},
    "bench":         {"source": "rtdetr", "threshold": 0.45},
    "fire hydrant":  {"source": "rtdetr", "threshold": 0.55},
    "trash bin":     {"source": "omdet",  "threshold": 0.65},
    "stroller":      {"source": "omdet",  "threshold": 0.45},
}

RT_DETR_DISTRACTION_LABELS = {
    cat for cat, cfg in DISTRACTION_CATEGORIES.items()
    if cfg["source"] == "rtdetr"
}
OMDET_PROMPTS = [
    cat for cat, cfg in DISTRACTION_CATEGORIES.items()
    if cfg["source"] == "omdet"
]

# Distraction ids live in their own high range so they can ride the
# existing remove_item_ids confirm field without colliding with
# belongings ids (0..n). Contract v3 stays additive.
DISTRACTION_ID_BASE = 10000

# An OmDet item whose SAM mask is at least this far inside the union
# of person + belonging + RT-DETR item masks is the SAME physical
# object the closed-vocab pass already named (calibration: OmDet
# "trash bin" fired on parking meters at 0.70 with near-identical
# boxes) and is suppressed — RT-DETR wins its own classes. Mask level,
# not box level: occlusion (a bin standing in front of a truck) has
# disjoint masks and must survive.
MASK_SUPPRESSION_FRACTION = 0.6

# Geometric dedupe: two distraction detections (any classes, either
# source) whose boxes overlap this much are one physical object.
DEDUPE_IOU_THRESHOLD = 0.5
DEDUPE_CONTAINMENT_THRESHOLD = 0.7


def box_iou(box_a: Sequence[float], box_b: Sequence[float]) -> float:
    x_a = max(box_a[0], box_b[0])
    y_a = max(box_a[1], box_b[1])
    x_b = min(box_a[2], box_b[2])
    y_b = min(box_a[3], box_b[3])
    inter = max(0.0, x_b - x_a) * max(0.0, y_b - y_a)
    area_a = (box_a[2] - box_a[0]) * (box_a[3] - box_a[1])
    area_b = (box_b[2] - box_b[0]) * (box_b[3] - box_b[1])
    union = float(area_a + area_b - inter)
    return inter / union if union > 0 else 0.0


def box_containment(
    inner: Sequence[float], outer: Sequence[float]
) -> float:
    """Fraction of `inner`'s area covered by `outer`."""
    x_a = max(inner[0], outer[0])
    y_a = max(inner[1], outer[1])
    x_b = min(inner[2], outer[2])
    y_b = min(inner[3], outer[3])
    inter = max(0.0, x_b - x_a) * max(0.0, y_b - y_a)
    area = float((inner[2] - inner[0]) * (inner[3] - inner[1]))
    return inter / area if area > 0 else 0.0


def _same_object(box_a: Sequence[float], box_b: Sequence[float]) -> bool:
    return (
        box_iou(box_a, box_b) >= DEDUPE_IOU_THRESHOLD
        or box_containment(box_a, box_b) >= DEDUPE_CONTAINMENT_THRESHOLD
        or box_containment(box_b, box_a) >= DEDUPE_CONTAINMENT_THRESHOLD
    )


def filter_by_threshold(
    detections: List[Dict[str, Any]],
    categories: Dict[str, Dict[str, Any]] = DISTRACTION_CATEGORIES,
) -> List[Dict[str, Any]]:
    """Keeps detections whose category is configured AND whose score
    clears that category's own threshold (the calibration gate's
    per-category bars — one global threshold would either flood the
    user with false bins or hide every traffic light)."""
    kept = []
    for det in detections:
        cfg = categories.get(det["label"])
        if cfg is not None and det["score"] >= cfg["threshold"]:
            kept.append(det)
    return kept


def dedupe_distractions(
    detections: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """One physical object = one item, whichever class/source fired.

    RT-DETR double-fires vehicles under two labels (a white car is
    also a "truck" at a lower score — the twin boxes are near
    identical) and OmDet can fire two prompts on one box. Highest
    score wins; deterministic order: score desc, then category, then
    box — so ids are stable between /detect and /process.
    """
    ordered = sorted(
        detections,
        key=lambda d: (-d["score"], d["label"], [int(v) for v in d["box"]]),
    )
    kept: List[Dict[str, Any]] = []
    for det in ordered:
        if any(_same_object(det["box"], k["box"]) for k in kept):
            continue
        kept.append(det)
    return kept


def build_distraction_candidates(
    rtdetr_detections: List[Dict[str, Any]],
    omdet_detections: List[Dict[str, Any]],
    categories: Dict[str, Dict[str, Any]] = DISTRACTION_CATEGORIES,
) -> List[Dict[str, Any]]:
    """Box-stage candidate list (before SAM masks exist): per-category
    thresholds, then ONE dedupe across both sources. RT-DETR entries
    sort ahead of OmDet entries at equal geometry because dedupe runs
    score-first and the RT twins measured higher — and where an OmDet
    box merely duplicates an RT object at a LOWER score it drops here;
    the remaining OmDet-vs-RT same-object cases are settled at mask
    level in suppress_omdet_duplicates().

    Returns [{'category', 'box', 'score', 'source'}] in dedupe order.
    Ids are assigned by the pipeline AFTER mask suppression.
    """
    rt = [
        {"category": d["label"], "box": d["box"], "score": d["score"],
         "source": "rtdetr"}
        for d in filter_by_threshold(rtdetr_detections, categories)
        if categories[d["label"]]["source"] == "rtdetr"
    ]
    om = [
        {"category": d["label"], "box": d["box"], "score": d["score"],
         "source": "omdet"}
        for d in filter_by_threshold(omdet_detections, categories)
        if categories[d["label"]]["source"] == "omdet"
    ]
    merged = [
        {"label": c["category"], "box": c["box"], "score": c["score"],
         "_candidate": c}
        for c in rt + om
    ]
    deduped = dedupe_distractions(merged)
    return [d["_candidate"] for d in deduped]


def mask_fraction_inside(
    mask: np.ndarray, union_mask: Optional[np.ndarray]
) -> float:
    """Fraction of `mask`'s pixels that lie inside `union_mask`."""
    if union_mask is None:
        return 0.0
    area = int((mask > 0).sum())
    if area == 0:
        return 0.0
    inside = int(((mask > 0) & (union_mask > 0)).sum())
    return inside / area


def suppress_omdet_duplicates(
    candidates: List[Dict[str, Any]],
    candidate_masks: List[np.ndarray],
    reference_masks: List[np.ndarray],
) -> Tuple[List[Dict[str, Any]], List[np.ndarray]]:
    """Mask-level suppression (see MASK_SUPPRESSION_FRACTION).

    `reference_masks` = person masks + belonging masks + RT-DETR
    distraction masks. Only OmDet-sourced candidates can be
    suppressed; RT-DETR candidates never are (RT-DETR wins its own
    classes — brief rule, and its dedupe already ran at box level).
    """
    if not reference_masks:
        return candidates, candidate_masks
    union = reference_masks[0].copy()
    for m in reference_masks[1:]:
        union = np.maximum(union, m)

    kept_c: List[Dict[str, Any]] = []
    kept_m: List[np.ndarray] = []
    for cand, mask in zip(candidates, candidate_masks):
        if cand["source"] == "omdet" and mask_fraction_inside(
            mask, union
        ) >= MASK_SUPPRESSION_FRACTION:
            continue
        kept_c.append(cand)
        kept_m.append(mask)
    return kept_c, kept_m


def clip_mask(mask: np.ndarray, protected_union: Optional[np.ndarray]) -> np.ndarray:
    """Removes every protected pixel from a removal mask (hard rule,
    plan §5 / design X11): a distraction overlapping the keeper loses
    the overlapping part, never the keeper."""
    if protected_union is None:
        return mask
    clipped = np.where(protected_union > 0, 0, mask).astype(mask.dtype)
    return clipped


def prepare_distraction_mask(
    raw_mask: np.ndarray,
    box: Sequence[float],
    protected_union: Optional[np.ndarray],
) -> np.ndarray:
    """Removal mask for an included distraction: hole fill + the
    pipeline's standard item dilation (max(8, 2% of box height) px,
    mirroring prepare_item_removal_mask), with protected-set clipping
    applied BEFORE and AFTER dilation — dilation must not grow the
    mask back into protected pixels."""
    clipped = clip_mask(raw_mask, protected_union)
    filled = fill_mask_holes(clipped)
    bh = max(1, int(box[3]) - int(box[1]))
    dilation_px = max(8, int(bh * 0.02))
    dilated = dilate_mask(filled, dilation_px)
    return clip_mask(dilated, protected_union)


def union_of(masks: List[np.ndarray]) -> Optional[np.ndarray]:
    if not masks:
        return None
    union = masks[0].copy()
    for m in masks[1:]:
        union = np.maximum(union, m)
    return union


class OmDetDetector:
    """OmDet-Turbo Tiny open-vocab detector (Apache-2.0).

    Weights: omlab/omdet-turbo-swin-tiny-hf (baked into the Modal
    image). Runs via stock transformers (needs >= 4.45; production
    pins 4.46.3). Lazy-loaded on first use; a load/inference failure
    raises — silent fallbacks are disabled in this codebase
    (PG_ALLOW_FALLBACKS only gates the dev heuristic in detector.py,
    and inventing distractions would be worse than failing the job).
    """

    MODEL_NAME = "omlab/omdet-turbo-swin-tiny-hf"
    # Capture floor: below every shipped threshold; per-category bars
    # are applied in filter_by_threshold.
    CAPTURE_THRESHOLD = 0.25
    NMS_THRESHOLD = 0.3

    def __init__(self, model_name: str = MODEL_NAME, device: Optional[str] = None):
        self.model_name = model_name
        self.device = device
        self._model = None
        self._processor = None
        self._initialized = False
        self.fallback_used = False

    def _lazy_init(self):
        if self._initialized:
            return
        self._initialized = True
        import torch
        from transformers import AutoProcessor, OmDetTurboForObjectDetection

        if self.device is None:
            self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self._processor = AutoProcessor.from_pretrained(self.model_name)
        self._model = OmDetTurboForObjectDetection.from_pretrained(
            self.model_name
        ).to(self.device)
        self._model.eval()

    def detect(
        self,
        image_np: np.ndarray,
        prompts: Optional[List[str]] = None,
    ) -> List[Dict[str, Any]]:
        """Runs OmDet ONCE for all prompts. Returns
        [{'box', 'score', 'label'}] with label = the prompt text that
        fired (identical to the COCO-style labels RT-DETR returns, so
        downstream code treats both sources uniformly)."""
        prompts = prompts if prompts is not None else list(OMDET_PROMPTS)
        if not prompts:
            return []
        self._lazy_init()
        import torch
        from PIL import Image

        h, w = image_np.shape[:2]
        pil_img = Image.fromarray(image_np)
        inputs = self._processor(
            images=pil_img, text=[prompts], return_tensors="pt"
        ).to(self.device)
        with torch.no_grad():
            outputs = self._model(**inputs)
        # Call shape mirrors the calibration harness exactly (it is
        # the code that produced the gate's evidence): `classes` maps
        # result indices back to prompt strings.
        results = self._processor.post_process_grounded_object_detection(
            outputs,
            classes=prompts,
            target_sizes=[(h, w)],
            score_threshold=self.CAPTURE_THRESHOLD,
            nms_threshold=self.NMS_THRESHOLD,
        )[0]

        detections = []
        for score, cls, box in zip(
            results["scores"], results["classes"], results["boxes"]
        ):
            b = box.tolist()
            x1 = max(0, int(round(b[0])))
            y1 = max(0, int(round(b[1])))
            x2 = min(w, int(round(b[2])))
            y2 = min(h, int(round(b[3])))
            if x2 > x1 and y2 > y1:
                detections.append({
                    "box": [x1, y1, x2, y2],
                    "score": float(score.item() if hasattr(score, "item") else score),
                    "label": prompts[int(cls)].lower(),
                })
        return detections


def omdet_available() -> bool:
    """Cheap import probe used by tests/diagnostics (does not load
    weights). Production never branches on this — a missing OmDet is
    a build error, surfaced by OmDetDetector itself."""
    try:
        import transformers

        return hasattr(transformers, "OmDetTurboForObjectDetection") and (
            os.getenv("PG_OMDET_DISABLED", "0") != "1"
        )
    except Exception:
        return False
