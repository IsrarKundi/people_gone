"""
Mask Preparation Module — PeopleGone Phase 0
Handles:
1. Union of remove masks
2. Interior hole filling
3. Dilation (2% to 5% of person height, floor ~8-16px)
4. Shadow expansion heuristic beneath/behind removed persons
"""

from typing import List, Dict, Any, Tuple
import numpy as np

def fill_mask_holes(binary_mask: np.ndarray) -> np.ndarray:
    """Fills interior holes in a binary mask (uint8 0 or 255)."""
    try:
        import cv2
        contours, hierarchy = cv2.findContours(
            binary_mask, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE
        )
        filled = binary_mask.copy()
        if hierarchy is not None:
            for i in range(len(contours)):
                cv2.drawContours(filled, contours, i, 255, -1)
        return filled
    except Exception:
        # Fallback with scipy
        from scipy import ndimage
        return ndimage.binary_fill_holes(binary_mask > 0).astype(np.uint8) * 255

def dilate_mask(binary_mask: np.ndarray, dilation_px: int) -> np.ndarray:
    """Dilates a binary mask by dilation_px."""
    if dilation_px <= 0:
        return binary_mask
    try:
        import cv2
        kernel = cv2.getStructuringElement(
            cv2.MORPH_ELLIPSE, (dilation_px * 2 + 1, dilation_px * 2 + 1)
        )
        return cv2.dilate(binary_mask, kernel, iterations=1)
    except Exception:
        from scipy import ndimage
        return ndimage.binary_dilation(
            binary_mask > 0, iterations=dilation_px
        ).astype(np.uint8) * 255

def expand_shadows(
    image_rgb: np.ndarray,
    mask: np.ndarray,
    box: List[int],
    max_shadow_expansion_px: int = 60
) -> np.ndarray:
    """
    Shadow expansion heuristic:
    Detects adjacent dark, low-saturation regions touching the person's lower boundary/feet,
    expanding the mask downward and outward plausibly.
    """
    h, w = mask.shape
    x1, y1, x2, y2 = box
    bw = max(1, x2 - x1)
    bh = max(1, y2 - y1)

    # Focus on lower 20% of the person's bounding box and area beneath feet
    feet_y1 = max(0, y2 - int(bh * 0.2))
    feet_y2 = min(h, y2 + max_shadow_expansion_px)
    search_x1 = max(0, x1 - int(bw * 0.3))
    search_x2 = min(w, x2 + int(bw * 0.3))

    if feet_y2 <= feet_y1 or search_x2 <= search_x1:
        return mask

    expanded_mask = mask.copy()

    # Convert RGB to HSV to inspect brightness and saturation
    try:
        import cv2
        roi_rgb = image_rgb[feet_y1:feet_y2, search_x1:search_x2]
        roi_hsv = cv2.cvtColor(roi_rgb, cv2.COLOR_RGB2HSV)
        # Saturation channel: roi_hsv[:, :, 1], Value channel: roi_hsv[:, :, 2]
        sat = roi_hsv[:, :, 1]
        val = roi_hsv[:, :, 2]

        # Shadow heuristic: dark (V < 130) and low-to-medium saturation (S < 140)
        shadow_candidates = (val < 130) & (sat < 140)

        # Region must connect to existing mask
        roi_mask = (mask[feet_y1:feet_y2, search_x1:search_x2] > 0)
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
        connected_shadow = cv2.dilate(roi_mask.astype(np.uint8), kernel, iterations=3) > 0
        final_shadow = shadow_candidates & connected_shadow

        expanded_mask[feet_y1:feet_y2, search_x1:search_x2] |= (final_shadow.astype(np.uint8) * 255)
    except Exception:
        # Fallback simple vertical foot expansion
        expanded_mask[y2:min(h, y2 + 15), x1:x2] = 255

    return expanded_mask

def prepare_individual_removal_masks(
    image_rgb: np.ndarray,
    persons: List[Dict[str, Any]],
    instance_masks: List[np.ndarray],
    remove_ids: set,
    dilation_factor: float = 0.02,
    shadow_mode: str = "v1"
) -> List[Dict[str, Any]]:
    """
    Prepares dilated and shadow-expanded masks per removed person.
    Returns list of dicts:
    [{'person_id': int, 'box': list, 'mask': np.ndarray, 'height': int}]

    shadow_mode:
      "v1" (default, Phase C) — the floor heuristic PLUS directional
          shadow growth from worker.shadow_growth, applied when a
          confident per-photo light direction exists (keeper-vetoed).
          Investigation + gate evidence:
          docs/architecture/phase-c-investigation.md.
      "legacy" — exactly the pre-Phase-C floor behaviour below.
    The mode is chosen explicitly by the caller
    (PipelineConfig.shadow_mode). There is no silent fallback: in
    "v1" mode, growth finding no confident direction adds nothing,
    by design, and the floor result stands.
    """
    if shadow_mode == "v1":
        # Lazy import: shadow_growth imports helpers from this
        # module, so a top-level import here would be circular.
        from .shadow_growth import prepare_masks_v1

        return prepare_masks_v1(
            image_rgb, persons, instance_masks, remove_ids,
            dilation_factor=dilation_factor,
        )
    if shadow_mode != "legacy":
        raise ValueError(f"unknown shadow_mode: {shadow_mode!r}")
    results = []
    for p, inst_mask in zip(persons, instance_masks):
        if p["id"] in remove_ids:
            filled = fill_mask_holes(inst_mask)
            bh = max(1, p["box"][3] - p["box"][1])
            dilation_px = max(8, int(bh * dilation_factor))
            dilated = dilate_mask(filled, dilation_px)
            shadow_exp = expand_shadows(image_rgb, dilated, p["box"])
            results.append({
                "person_id": p["id"],
                "box": p["box"],
                "mask": shadow_exp,
                "height": bh
            })
    return results

def prepare_combined_removal_mask(
    image_rgb: np.ndarray,
    persons: List[Dict[str, Any]],
    instance_masks: List[np.ndarray],
    remove_ids: set,
    dilation_factor: float = 0.02
) -> np.ndarray:
    """
    Unions remove masks, dilates each by dilation_factor * height,
    applies shadow expansion, and returns the final combined mask.
    """
    h, w = image_rgb.shape[:2]
    combined_mask = np.zeros((h, w), dtype=np.uint8)
    individual_preps = prepare_individual_removal_masks(
        image_rgb, persons, instance_masks, remove_ids, dilation_factor=dilation_factor
    )
    for item in individual_preps:
        combined_mask = np.maximum(combined_mask, item["mask"])
    return combined_mask
