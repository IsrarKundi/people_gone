"""Racing inpainter — MAT vs PowerPaint on large patches (§6.5).

MAT-class fills smear on large holes (Phase 0 evidence), so for a large
patch both engines run and the candidate with the lower ghost-check
residual score (sum of person-detection scores inside the filled crop;
0.0 = no person-like residual = best) wins. Small patches never pay
PowerPaint's cost: they always use MAT only.

Every call appends a record to self.records so the caller can surface
exactly which engine filled which crop, with timings and residuals.
Fails loudly: any engine or scoring error propagates — no fallback.

Winner rule (Phase E revision 3 — PERSON VETO first): product law —
a fill containing a newly invented PERSON is an automatic reject,
regardless of texture quality or residuals (an all-PP wedding
composite re-drew a whole phantom woman into the person-shaped hole,
2026-10-22). So before any scoring, each candidate gets a detector
pass and any confident person detection substantially inside the
FILLED MASK disqualifies PowerPaint for that crop (MAT fills instead;
MAT never invents people — its worst case is smear). The veto mirrors
the region-overlap test in worker.ghost_check's distraction residuals.

Only if PP survives the veto does the older scoring apply: the ghost
residual (sum of person-detection scores across the whole crop) is
noisy run-to-run and contaminated by real context people, so it is
used only as a coarse bar — PP must be under an absolute cleanliness
bar AND not worse than MAT by more than the margin.
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

# Person veto: a detection counts as "a person IN the fill" when at
# least this fraction of its box is covered by filled-mask pixels.
PERSON_VETO_OVERLAP = float(os.environ.get("PG_PP_VETO_OVERLAP", "0.35"))


class RacingInpainter:
    def __init__(self, mat_inpainter, pp_inpainter, detector):
        self.mat_inpainter = mat_inpainter
        self.pp_inpainter = pp_inpainter
        self.detector = detector
        self.records: List[Dict[str, Any]] = []
        self.fallback_used: bool = False

    def _candidate_detections(self, candidate: np.ndarray) -> list:
        """One detector pass per candidate; both the residual sum and
        the person veto are derived from this single list."""
        from worker.ghost_check import check_for_ghost_residuals

        h, w = candidate.shape[:2]
        _fired, residuals = check_for_ghost_residuals(
            candidate, (0, 0, w, h), self.detector, GHOST_CONFIDENCE_THRESH
        )
        return residuals

    @staticmethod
    def _residual_score(detections: list) -> float:
        return float(sum(float(d.get("score", 0.0)) for d in detections))

    @staticmethod
    def _person_hits(detections: list, mask_crop: np.ndarray) -> list:
        """Detections standing IN the fill: box substantially covered
        by filled-mask pixels. A keeper cannot be hit — keeper pixels
        are carved out of the removal mask before inpainting, and a
        box merely straddling the fill edge scores below the overlap
        bar. Product law: any hit on the PP candidate vetoes it."""
        filled = mask_crop > 127
        if not filled.any():
            return []
        hits = []
        for d in detections:
            x0, y0, x1, y1 = (int(round(float(v))) for v in d["box"])
            x0, y0 = max(0, x0), max(0, y0)
            x1, y1 = min(filled.shape[1], x1), min(filled.shape[0], y1)
            if x1 <= x0 or y1 <= y0:
                continue
            box_area = (x1 - x0) * (y1 - y0)
            covered = int(filled[y0:y1, x0:x1].sum())
            overlap = covered / box_area if box_area else 0.0
            if overlap >= PERSON_VETO_OVERLAP:
                hits.append(
                    {
                        "box": [x0, y0, x1, y1],
                        "score": round(float(d.get("score", 0.0)), 3),
                        "mask_overlap": round(float(overlap), 3),
                    }
                )
        return hits

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

        mat_dets = self._candidate_detections(mat_candidate)
        pp_dets = self._candidate_detections(pp_candidate)
        mat_residual = self._residual_score(mat_dets)
        pp_residual = self._residual_score(pp_dets)
        pp_hits = self._person_hits(pp_dets, mask_crop)
        mat_hits = self._person_hits(mat_dets, mask_crop)

        # PERSON VETO first (product law): an invented person in the PP
        # fill disqualifies it for this crop, whatever the scores say.
        if pp_hits:
            winner, result, win_reason = "mat", mat_candidate, "pp_person_veto"
        elif pp_residual <= PP_CLEAN_MAX and pp_residual <= mat_residual + PP_WIN_MARGIN:
            winner, result, win_reason = "powerpaint", pp_candidate, "pp_clean"
        else:
            winner, result, win_reason = "mat", mat_candidate, "mat_default"

        self.records.append(
            {
                "mask_ratio": round(float(mask_ratio), 6),
                "mask_area_px": mask_area,
                "raced": True,
                "winner": winner,
                "win_reason": win_reason,
                "mat_residual": mat_residual,
                "pp_residual": pp_residual,
                "pp_win_margin": PP_WIN_MARGIN,
                "pp_clean_max": PP_CLEAN_MAX,
                "pp_person_hits": pp_hits,
                "mat_person_hits": mat_hits,
                "mat_ms": round(mat_ms, 1),
                "pp_ms": round(pp_ms, 1),
            }
        )
        return result
