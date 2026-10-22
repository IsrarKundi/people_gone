"""Racing inpainter — MAT vs PowerPaint on large patches (§6.5).

MAT-class fills smear on large holes (Phase 0 evidence), so for a large
patch both engines run and the candidate with the lower ghost-check
residual score (sum of person-detection scores inside the filled crop;
0.0 = no person-like residual = best) wins. Small patches never pay
PowerPaint's cost: they always use MAT only.

Every call appends a record to self.records so the caller can surface
exactly which engine filled which crop, with timings and residuals.
Fails loudly: any engine or scoring error propagates — no fallback.

Winner rule (Phase E revision 2): the ghost residual detects leftover
person-shapes only; it cannot judge fill realism — and it is noisy
(identical MAT candidates scored 1.63 and 2.53 in consecutive live
runs). But its absolute level carries one vital signal: a HIGH
PowerPaint residual can mean PP invented a person. On the 2026-10-22
wedding photo, an all-PP composite re-drew a whole phantom woman into
the person-shaped hole (PP residuals 1.87–2.42), while PP's clean
winning fills scored 0.91–0.93; MAT never invents people, its worst
case is smear. Failure costs are asymmetric (phantom person =
product-fatal, smear = ugly), so PP wins a raced crop only when its
residual is BOTH under an absolute cleanliness bar AND not worse than
MAT's by more than the margin.
"""
import os
import time
from typing import Any, Dict, List

import numpy as np

# A crop races only when the hole is both relatively large within its
# crop AND large in absolute pixels.
LARGE_PATCH_MASK_RATIO = 0.15
LARGE_PATCH_MIN_AREA_PX = 40000

GHOST_CONFIDENCE_THRESH = 0.30

# PowerPaint wins a raced crop when pp_residual <= mat_residual + margin
# AND pp_residual <= PP_CLEAN_MAX (absolute bar — see docstring).
PP_WIN_MARGIN = float(os.environ.get("PG_PP_WIN_MARGIN", "0.5"))
PP_CLEAN_MAX = float(os.environ.get("PG_PP_CLEAN_MAX", "1.0"))


class RacingInpainter:
    def __init__(self, mat_inpainter, pp_inpainter, detector):
        self.mat_inpainter = mat_inpainter
        self.pp_inpainter = pp_inpainter
        self.detector = detector
        self.records: List[Dict[str, Any]] = []
        self.fallback_used: bool = False

    def _residual_score(self, candidate: np.ndarray) -> float:
        from worker.ghost_check import check_for_ghost_residuals

        h, w = candidate.shape[:2]
        _fired, residuals = check_for_ghost_residuals(
            candidate, (0, 0, w, h), self.detector, GHOST_CONFIDENCE_THRESH
        )
        return float(sum(float(d.get("score", 0.0)) for d in residuals))

    def inpaint_crop(self, image_crop: np.ndarray, mask_crop: np.ndarray) -> np.ndarray:
        """image_crop: RGB uint8 (H, W, 3). mask_crop: uint8 (H, W), >0 = inpaint."""
        self.fallback_used = False
        mask_area = int((mask_crop > 127).sum())
        mask_ratio = mask_area / mask_crop.size if mask_crop.size else 0.0
        raced = (
            mask_ratio >= LARGE_PATCH_MASK_RATIO
            and mask_area >= LARGE_PATCH_MIN_AREA_PX
        )

        if not raced:
            t0 = time.perf_counter()
            result = self.mat_inpainter.inpaint_crop(image_crop, mask_crop)
            mat_ms = (time.perf_counter() - t0) * 1000.0
            self.records.append(
                {
                    "mask_ratio": round(float(mask_ratio), 6),
                    "mask_area_px": mask_area,
                    "raced": False,
                    "winner": "mat",
                    "mat_residual": None,
                    "pp_residual": None,
                    "mat_ms": round(mat_ms, 1),
                    "pp_ms": None,
                }
            )
            return result

        t0 = time.perf_counter()
        mat_candidate = self.mat_inpainter.inpaint_crop(image_crop, mask_crop)
        mat_ms = (time.perf_counter() - t0) * 1000.0

        t0 = time.perf_counter()
        pp_candidate = self.pp_inpainter.inpaint_crop(image_crop, mask_crop)
        pp_ms = (time.perf_counter() - t0) * 1000.0

        mat_residual = self._residual_score(mat_candidate)
        pp_residual = self._residual_score(pp_candidate)

        # PowerPaint wins only under the absolute cleanliness bar AND
        # within the margin vs MAT (see module docstring, revision 2).
        if pp_residual <= PP_CLEAN_MAX and pp_residual <= mat_residual + PP_WIN_MARGIN:
            winner, result = "powerpaint", pp_candidate
        else:
            winner, result = "mat", mat_candidate

        self.records.append(
            {
                "mask_ratio": round(float(mask_ratio), 6),
                "mask_area_px": mask_area,
                "raced": True,
                "winner": winner,
                "mat_residual": mat_residual,
                "pp_residual": pp_residual,
                "pp_win_margin": PP_WIN_MARGIN,
                "pp_clean_max": PP_CLEAN_MAX,
                "mat_ms": round(mat_ms, 1),
                "pp_ms": round(pp_ms, 1),
            }
        )
        return result
