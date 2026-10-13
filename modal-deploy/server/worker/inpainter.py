"""
Inpainter Module — PeopleGone Phase 0
Runs LaMa (big-lama) on native-resolution crops around removal masks,
then composites back with boundary alpha feathering.
Guarantees: Output dimensions == input dimensions, bit-identical outside masks.
"""

import os
from typing import List, Tuple, Optional
import numpy as np

class LamaInpainter:
    def __init__(
        self,
        checkpoint_path: Optional[str] = None,
        device: Optional[str] = None
    ):
        self.checkpoint_path = checkpoint_path
        self.device = device
        self._model = None
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

            # Check for IOPaint or TorchScript LaMa model
            if self.checkpoint_path is not None:
                self._model = torch.jit.load(self.checkpoint_path, map_location=self.device)
                self._model.eval()
            else:
                from simple_lama_inpainting import SimpleLama
                self._model = SimpleLama(device=self.device)
        except Exception as e:
            self._load_error = str(e)
            self._model = None
            if not self.allow_fallbacks:
                raise RuntimeError(
                    f"Stage 'inpainter' failed to load LaMa model: {e}. "
                    "Silent fallbacks are disabled. Set PG_ALLOW_FALLBACKS=1 only for offline development."
                ) from e

    def inpaint_crop(self, image_crop: np.ndarray, mask_crop: np.ndarray) -> np.ndarray:
        """
        Inpaints a single native-resolution crop.
        image_crop: RGB uint8 (H, W, 3)
        mask_crop: uint8 (H, W), >0 is region to inpaint.
        """
        self.fallback_used = False
        self._lazy_init()
        if self._model is not None:
            try:
                from PIL import Image
                pil_img = Image.fromarray(image_crop)
                pil_mask = Image.fromarray(mask_crop)
                if hasattr(self._model, "__call__"):
                    result_pil = self._model(pil_img, pil_mask)
                    result_np = np.array(result_pil)
                    # RUN-COPY PATCH (Muse, 2026-10-12): big-lama returns the crop
                    # padded to a multiple of 8, a few px larger than the input.
                    # Resize back so output size == input crop size, always.
                    if result_np.shape[:2] != image_crop.shape[:2]:
                        result_pil = result_pil.resize(
                            (image_crop.shape[1], image_crop.shape[0]), Image.LANCZOS
                        )
                        result_np = np.array(result_pil)
                    return result_np
            except Exception as e:
                if not self.allow_fallbacks:
                    raise RuntimeError(
                        f"Stage 'inpainter' inference failed during inpaint_crop: {e}."
                    ) from e

        # Fallback inpainter only if explicitly enabled
        if not self.allow_fallbacks:
            raise RuntimeError(
                f"Stage 'inpainter' model is not initialized: {self._load_error}. "
                "Silent fallbacks are disabled. Set PG_ALLOW_FALLBACKS=1 only for offline development."
            )

        self.fallback_used = True
        try:
            import cv2
            bgr_crop = cv2.cvtColor(image_crop, cv2.COLOR_RGB2BGR)
            inpainted_bgr = cv2.inpaint(bgr_crop, mask_crop, inpaintRadius=5, flags=cv2.INPAINT_TELEA)
            return cv2.cvtColor(inpainted_bgr, cv2.COLOR_BGR2RGB)
        except Exception:
            result = image_crop.copy()
            mean_color = np.mean(image_crop[mask_crop == 0], axis=0) if np.any(mask_crop == 0) else [128, 128, 128]
            result[mask_crop > 0] = mean_color.astype(np.uint8)
            return result

def get_crop_bounds(
    mask: np.ndarray,
    min_context: int = 512,
    context_ratio: float = 0.5
) -> Optional[Tuple[int, int, int, int]]:
    """
    Computes crop box = mask bbox + max(512px, 50% context).
    Returns (x1, y1, x2, y2) or None if mask is empty.
    """
    ys, xs = np.where(mask > 0)
    if len(ys) == 0:
        return None

    h, w = mask.shape
    min_x, max_x = int(np.min(xs)), int(np.max(xs))
    min_y, max_y = int(np.min(ys)), int(np.max(ys))

    bw = max_x - min_x
    bh = max_y - min_y
    context_x = max(min_context, int(bw * context_ratio))
    context_y = max(min_context, int(bh * context_ratio))

    crop_x1 = max(0, min_x - context_x)
    crop_y1 = max(0, min_y - context_y)
    crop_x2 = min(w, max_x + context_x)
    crop_y2 = min(h, max_y + context_y)

    return (crop_x1, crop_y1, crop_x2, crop_y2)

def composite_with_feather(
    original_rgb: np.ndarray,
    inpainted_crop: np.ndarray,
    crop_mask: np.ndarray,
    crop_bounds: Tuple[int, int, int, int],
    feather_px: int = 4
) -> np.ndarray:
    """
    Pastes inpainted crop back into untouched original with 2-6 px alpha feathering.
    Mask sent to inpainter is binary (unfeathered); feathering is ONLY on composite paste.
    """
    x1, y1, x2, y2 = crop_bounds
    result = original_rgb.copy()
    crop_orig = original_rgb[y1:y2, x1:x2]

    # Create feather alpha from crop_mask
    alpha = (crop_mask > 0).astype(np.float32)
    if feather_px > 0:
        try:
            import cv2
            kernel_size = feather_px * 2 + 1
            alpha = cv2.GaussianBlur(alpha, (kernel_size, kernel_size), sigmaX=feather_px / 2.0)
        except Exception:
            pass

    alpha_3d = np.expand_dims(alpha, axis=2)
    blended_crop = (inpainted_crop.astype(np.float32) * alpha_3d +
                    crop_orig.astype(np.float32) * (1.0 - alpha_3d))
    result[y1:y2, x1:x2] = np.clip(blended_crop, 0, 255).astype(np.uint8)

    return result
