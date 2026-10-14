"""
Ghost Check Module — PeopleGone Phase 0
Second-pass verification: runs detector on composited result to identify leftover artifacts.
"""

from typing import List, Dict, Any, Tuple
import numpy as np

def check_for_ghost_residuals(
    composited_image: np.ndarray,
    crop_bounds: Tuple[int, int, int, int],
    detector: Any,
    confidence_thresh: float = 0.30
) -> Tuple[bool, List[Dict[str, Any]]]:
    """
    Runs detector on the inpainted crop area.
    Returns (ghost_detected: bool, residual_detections: list).
    """
    x1, y1, x2, y2 = crop_bounds
    crop = composited_image[y1:y2, x1:x2]
    if crop.size == 0:
        return False, []

    # Detect in the crop
    detections = detector.detect_persons(crop)
    residuals = [d for d in detections if d.get("score", 0.0) >= confidence_thresh]

    return (len(residuals) > 0), residuals

def check_for_belongings_residuals(
    composited_image: np.ndarray,
    crop_bounds: Tuple[int, int, int, int],
    detector: Any,
    confidence_thresh: float = 0.30
) -> Tuple[bool, List[Dict[str, Any]]]:
    """
    Phase A extension (FR-08): same second-pass idea for belongings —
    runs the belongings-class detection on an inpainted crop that
    contained an attached or user-included item. A surviving item
    (e.g. half a bag the fill missed) fires a retry, exactly like a
    surviving person does.
    """
    x1, y1, x2, y2 = crop_bounds
    crop = composited_image[y1:y2, x1:x2]
    if crop.size == 0:
        return False, []

    detections = detector.detect_belongings(crop)
    residuals = [d for d in detections if d.get("score", 0.0) >= confidence_thresh]

    return (len(residuals) > 0), residuals

def check_for_distraction_residuals(
    composited_image: np.ndarray,
    crop_bounds: Tuple[int, int, int, int],
    category: str,
    source: str,
    original_box: List[int],
    rtdetr_detector: Any,
    omdet_detector: Any = None,
    confidence_thresh: float = 0.30
) -> Tuple[bool, List[Dict[str, Any]]]:
    """
    Phase B extension: same second-pass idea for a removed
    distraction. Re-detects the item's OWN category on the finished
    crop WITH THE SAME DETECTOR that found it (RT-DETR categories via
    the RT-DETR detector; OmDet prompts via OmDet). A residual counts
    only when it lands on the original item — its box must overlap
    the original box by at least 30% of the residual's own area —
    so an unrelated same-class object elsewhere in the (context-
    expanded) crop does not fire a pointless retry.
    """
    x1, y1, x2, y2 = crop_bounds
    crop = composited_image[y1:y2, x1:x2]
    if crop.size == 0:
        return False, []

    if source == "omdet":
        if omdet_detector is None:
            return False, []
        detections = omdet_detector.detect(crop, prompts=[category])
    else:
        detections = rtdetr_detector.detect_category(crop, category)

    # Original box in crop coordinates.
    ox1 = max(0, original_box[0] - x1)
    oy1 = max(0, original_box[1] - y1)
    ox2 = min(crop.shape[1], original_box[2] - x1)
    oy2 = min(crop.shape[0], original_box[3] - y1)
    if ox2 <= ox1 or oy2 <= oy1:
        return False, []

    residuals = []
    for d in detections:
        if d.get("score", 0.0) < confidence_thresh:
            continue
        b = d["box"]
        ix = max(0, min(b[2], ox2) - max(b[0], ox1))
        iy = max(0, min(b[3], oy2) - max(b[1], oy1))
        inter = ix * iy
        area = max(1, (b[2] - b[0]) * (b[3] - b[1]))
        if inter / area >= 0.30:
            residuals.append(d)

    return (len(residuals) > 0), residuals
