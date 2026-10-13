"""
Instance Segmentor Module — PeopleGone Phase 0
Uses Meta SAM 2.1 (Apache-2.0) prompted with person bounding boxes.
"""

import os
from typing import List, Dict, Any, Optional
import numpy as np

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
                for item in boxes:
                    box = np.array(item["box"], dtype=np.float32)
                    pred_masks, scores, _ = self._predictor.predict(
                        box=box[None, :],
                        multimask_output=False
                    )
                    best_mask = (pred_masks[0] > 0).astype(np.uint8) * 255
                    masks.append(best_mask)
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
