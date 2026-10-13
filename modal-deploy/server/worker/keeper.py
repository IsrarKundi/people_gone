"""
Keeper Selection Module — PeopleGone Phase 0
Implements §6.4 Step 4 heuristic:
score = 0.4*area + 0.25*centrality + 0.2*sharpness + 0.15*foreground
Top instance = keeper; if top-two overlap/touch at similar scale, both are keepers.
Supports ground-truth keep override.
"""

from typing import List, Dict, Any, Optional, Tuple, Set
import numpy as np

def compute_laplacian_sharpness(crop_rgb: np.ndarray) -> float:
    """Computes variance of Laplacian on grayscale crop as a proxy for sharpness."""
    if crop_rgb.size == 0:
        return 0.0
    try:
        import cv2
        gray = cv2.cvtColor(crop_rgb, cv2.COLOR_RGB2GRAY)
        lap = cv2.Laplacian(gray, cv2.CV_64F)
        return float(lap.var())
    except Exception:
        # Fallback without cv2
        gray = np.mean(crop_rgb, axis=2)
        dy, dx = np.gradient(gray)
        return float(np.var(dx) + np.var(dy))

def calculate_iou(boxA: List[int], boxB: List[int]) -> float:
    """Calculates Intersection over Union between two boxes."""
    xA = max(boxA[0], boxB[0])
    yA = max(boxA[1], boxB[1])
    xB = min(boxA[2], boxB[2])
    yB = min(boxA[3], boxB[3])

    inter = max(0, xB - xA) * max(0, yB - yA)
    areaA = (boxA[2] - boxA[0]) * (boxA[3] - boxA[1])
    areaB = (boxB[2] - boxB[0]) * (boxB[3] - boxB[1])

    union = float(areaA + areaB - inter)
    return inter / union if union > 0 else 0.0

def classify_keepers_and_removals(
    image_np: np.ndarray,
    persons: List[Dict[str, Any]],
    explicit_keep_ids: Optional[List[int]] = None,
    weights: Tuple[float, float, float, float] = (0.4, 0.25, 0.2, 0.15)
) -> Tuple[Set[int], Set[int], List[Dict[str, Any]]]:
    """
    Classifies detected persons into keeper IDs and remove IDs.
    Returns:
        (keeper_ids, remove_ids, scored_persons)
    """
    if not persons:
        return set(), set(), []

    # If explicit ground-truth override provided (batch mode / pinned ground truth)
    if explicit_keep_ids is not None:
        explicit_set = set(explicit_keep_ids)
        all_ids = {p["id"] for p in persons}
        keepers = explicit_set.intersection(all_ids)
        # If none matched, ensure at least primary keeper fallback
        if not keepers and all_ids:
            keepers = {persons[0]["id"]}
        removals = all_ids - keepers
        return keepers, removals, persons

    h, w = image_np.shape[:2]
    total_area = float(h * w)
    img_cx, img_cy = w / 2.0, h / 2.0
    max_dist = np.hypot(img_cx, img_cy)

    w_area, w_cent, w_sharp, w_fore = weights
    scored_persons = []
    sharpnesses = []

    # Precompute sharpness for relative normalization
    for p in persons:
        x1, y1, x2, y2 = p["box"]
        crop = image_np[y1:y2, x1:x2]
        sharpness = compute_laplacian_sharpness(crop)
        sharpnesses.append(sharpness)

    max_sharp = max(sharpnesses) if sharpnesses and max(sharpnesses) > 0 else 1.0

    for idx, p in enumerate(persons):
        x1, y1, x2, y2 = p["box"]
        bw = max(1, x2 - x1)
        bh = max(1, y2 - y1)
        area = float(bw * bh)

        # 1. Relative area (0.0 to 1.0)
        rel_area = min(1.0, area / (total_area * 0.4 + 1e-5))

        # 2. Centrality (1.0 = center, 0.0 = corner)
        cx, cy = (x1 + x2) / 2.0, (y1 + y2) / 2.0
        dist = np.hypot(cx - img_cx, cy - img_cy)
        centrality = max(0.0, 1.0 - (dist / (max_dist + 1e-5)))

        # 3. Upper body / face sharpness
        sharp_norm = min(1.0, sharpnesses[idx] / (max_sharp + 1e-5))

        # 4. Foreground cues (lower in the frame = closer to camera)
        bottom_y = float(y2) / float(h)
        foreground = min(1.0, max(0.0, bottom_y))

        composite_score = (
            w_area * rel_area +
            w_cent * centrality +
            w_sharp * sharp_norm +
            w_fore * foreground
        )

        p_copy = dict(p)
        p_copy["score_details"] = {
            "rel_area": rel_area,
            "centrality": centrality,
            "sharpness": sharp_norm,
            "foreground": foreground,
            "composite": composite_score,
            "raw_area": area
        }
        scored_persons.append(p_copy)

    # Sort descending by composite score
    scored_persons.sort(key=lambda x: x["score_details"]["composite"], reverse=True)

    # Keeper decision rule
    keeper_ids = {scored_persons[0]["id"]}

    # Couple / multi-subject rule:
    # If top two overlap or touch at similar scale (area ratio within 0.7 - 1.4), both are keepers
    if len(scored_persons) >= 2:
        top1 = scored_persons[0]
        top2 = scored_persons[1]
        area1 = top1["score_details"]["raw_area"]
        area2 = top2["score_details"]["raw_area"]
        area_ratio = min(area1, area2) / (max(area1, area2) + 1e-5)

        iou = calculate_iou(top1["box"], top2["box"])
        # Check proximity / overlap
        b1, b2 = top1["box"], top2["box"]
        horizontal_dist = max(0, max(b1[0], b2[0]) - min(b1[2], b2[2]))
        close_together = horizontal_dist < (0.15 * w)

        if area_ratio >= 0.65 and (iou > 0.05 or close_together):
            keeper_ids.add(top2["id"])

    all_ids = {p["id"] for p in persons}
    remove_ids = all_ids - keeper_ids

    return keeper_ids, remove_ids, scored_persons
