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
