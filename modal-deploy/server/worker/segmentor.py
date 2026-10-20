"""
Instance Segmentor Module — PeopleGone Phase 0
Uses Meta SAM 2.1 (Apache-2.0) prompted with person bounding boxes.
"""

import logging
import os
from typing import List, Dict, Any, Optional
import cv2
import numpy as np

logger = logging.getLogger(__name__)

# Negative-point refinement (overlap fix Phase 2, 2026-10-20): when
# two boxes overlap, each mask is re-predicted with negative points
# sampled from the OTHER person's confident interior, so SAM stops
# leaking across the contact boundary in both directions.
MAX_NEG_POINTS = 8
MIN_NEG_SEPARATION_PX = 15
REFINE_MIN_AREA_FRAC = 0.5
REFINE_MAX_AREA_FRAC = 1.5


def boxes_overlap(a: List[int], b: List[int]) -> bool:
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def sample_negative_points(
    own_mask: np.ndarray,
    other_union: np.ndarray,
    box: List[int],
    max_points: int = MAX_NEG_POINTS,
) -> np.ndarray:
    """(N, 2) float32 (x, y) points that are confidently the OTHER
    person: inside other_union, NOT claimed by own_mask, inside
    this box, eroded to the interior (never on a contested edge),
    greedily spaced by distance-to-boundary depth. Empty (0, 2)
    when no confident region exists — the caller then keeps the
    box-only mask. Pure numpy/cv2: unit-tested without SAM.
    """
    empty = np.zeros((0, 2), dtype=np.float32)
    region = (other_union > 0) & ~(own_mask > 0)
    x1, y1, x2, y2 = [int(v) for v in box]
    clip = np.zeros(region.shape, dtype=bool)
    clip[max(0, y1):y2, max(0, x1):x2] = True
    region &= clip
    if not region.any():
        return empty
    # Interior only: erode so sampled points sit deep inside the
    # other person, never on a boundary SAM might legitimately own.
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    confident = cv2.erode(region.astype(np.uint8), kernel) > 0
    if not confident.any():
        confident = region
    dist = cv2.distanceTransform(confident.astype(np.uint8), cv2.DIST_L2, 5)
    ys, xs = np.nonzero(confident)
    order = np.argsort(-dist[ys, xs])
    picked: List[tuple] = []
    for idx in order:
        x, y = int(xs[idx]), int(ys[idx])
        if all((x - px) ** 2 + (y - py) ** 2 >= MIN_NEG_SEPARATION_PX ** 2
               for px, py in picked):
            picked.append((x, y))
            if len(picked) >= max_points:
                break
    if not picked:
        return empty
    return np.array(picked, dtype=np.float32)

class SamSegmentor:
    def __init__(
        self,
        checkpoint: str = "facebook/sam2.1-hiera-tiny",
        device: Optional[str] = None
    ):
        self.checkpoint = checkpoint
        self.device = device
        self._predictor = None
        self._initialized = False
        self._load_error: Optional[str] = None
        self.fallback_used: bool = False

    @property
    def allow_fallbacks(self) -> bool:
        return os.getenv("PG_ALLOW_FALLBACKS", "0") == "1"

    def _lazy_init(self):
        if self._initialized:
            return
        self._initialized = True
        try:
            import torch
            if self.device is None:
                self.device = "cuda" if torch.cuda.is_available() else "cpu"

            # Check if sam2 library is installed
            from sam2.sam2_image_predictor import SAM2ImagePredictor
            self._predictor = SAM2ImagePredictor.from_pretrained(self.checkpoint, device=self.device)
        except Exception as e:
            self._load_error = str(e)
            self._predictor = None
            if not self.allow_fallbacks:
                raise RuntimeError(
                    f"Stage 'segmentor' failed to load SAM 2.1 model '{self.checkpoint}': {e}. "
                    "Silent fallbacks are disabled. Set PG_ALLOW_FALLBACKS=1 only for offline development."
                ) from e

    def segment_boxes(
        self,
        image_np: np.ndarray,
        boxes: List[Dict[str, Any]]
    ) -> List[np.ndarray]:
        """
        Segments persons given image and bounding boxes.
        Returns a list of boolean or uint8 binary masks of shape (H, W),
        one mask per bounding box.
        """
        self.fallback_used = False
        h, w = image_np.shape[:2]
        self._lazy_init()

        masks = []
        if self._predictor is not None and len(boxes) > 0:
            try:
                self._predictor.set_image(image_np)
                # Pass 1: box-only masks, exactly as before.
                for item in boxes:
                    box = np.array(item["box"], dtype=np.float32)
                    pred_masks, scores, _ = self._predictor.predict(
                        box=box[None, :],
                        multimask_output=False
                    )
                    best_mask = (pred_masks[0] > 0).astype(np.uint8) * 255
                    masks.append(best_mask)
                # Pass 2 (overlap fix Phase 2): where boxes overlap,
                # re-predict with negative points sampled from the
                # other person's confident interior — SAM then keeps
                # each mask on its own side of the contact boundary.
                # The refined mask is adopted only when sane
                # (non-empty, area within the accepted band of the
                # pass-1 mask); a refinement error keeps the real
                # pass-1 SAM mask (logged, never fabricated).
                box_list = [item["box"] for item in boxes]
                for i, item in enumerate(boxes):
                    others = np.zeros((h, w), dtype=np.uint8)
                    overlapped = False
                    for j, other in enumerate(boxes):
                        if j != i and boxes_overlap(box_list[i], box_list[j]):
                            others = np.maximum(others, masks[j])
                            overlapped = True
                    if not overlapped:
                        continue
                    pts = sample_negative_points(masks[i], others, box_list[i])
                    if len(pts) < 2:
                        continue
                    try:
                        pred_masks, _, _ = self._predictor.predict(
                            point_coords=pts,
                            point_labels=np.zeros(len(pts), dtype=np.int32),
                            box=np.array(box_list[i], dtype=np.float32)[None, :],
                            multimask_output=False
                        )
                        refined = (pred_masks[0] > 0).astype(np.uint8) * 255
                    except Exception as e:
                        logger.warning(
                            "negative-point refinement failed for box %s: %s",
                            box_list[i], e,
                        )
                        continue
                    area1 = int((masks[i] > 0).sum())
                    area2 = int((refined > 0).sum())
                    if area2 > 0 and area1 > 0 and (
                        REFINE_MIN_AREA_FRAC * area1
                        <= area2
                        <= REFINE_MAX_AREA_FRAC * area1
                    ):
                        masks[i] = refined
                return masks
            except Exception as e:
                if not self.allow_fallbacks:
                    raise RuntimeError(
                        f"Stage 'segmentor' inference failed on '{self.checkpoint}': {e}."
                    ) from e

        # Fallback mask generator only if explicitly enabled
        if not self.allow_fallbacks:
            raise RuntimeError(
                f"Stage 'segmentor' model '{self.checkpoint}' is not initialized: {self._load_error}. "
                "Silent fallbacks are disabled. Set PG_ALLOW_FALLBACKS=1 only for offline development."
            )

        self.fallback_used = True
        for item in boxes:
            x1, y1, x2, y2 = item["box"]
            mask = np.zeros((h, w), dtype=np.uint8)
            bw = max(1, x2 - x1)
            bh = max(1, y2 - y1)
            cx = (x1 + x2) // 2
            cy = (y1 + y2) // 2

            # Elliptical human silhouette approximation
            Y, X = np.ogrid[:h, :w]
            rx = bw / 2.0
            ry = bh / 2.0
            ellipse = ((X - cx) ** 2) / (rx ** 2 + 1e-5) + ((Y - cy) ** 2) / (ry ** 2 + 1e-5) <= 1.0
            mask[ellipse] = 255
            masks.append(mask)

        return masks
