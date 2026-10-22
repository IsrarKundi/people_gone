"""
Engine routing — the owner's rule (decided 2026-10-23).

Applied per PHOTO when the client asks for engine="auto" (explicit
"mat" / "lama" / "rorem" requests are forced and never routed):

    R = number of persons being removed in the job
    R < 3                                          -> RORem
    a removal touches a keeper's guard zone
        AND R < 8                                  -> RORem
    otherwise                                      -> MAT

One engine fills the whole photo — never a mix per crop. "Touches
the guard zone" = the removed person's RAW SAM mask intersects the
keeper guard zone (keeper mask dilated by KEEPER_GUARD_PX, the
mask_prep geometry the overlap fix already uses): the two are in
contact, or within the guard band of each other.

Fallback: under "auto" a RORem failure must not fail the user's
clean — FallbackInpainter completes the job with MAT and the
pipeline records engine_used="mat" /
routing_reason="rorem_failed_fallback". Under an explicit
engine="rorem" there is no wrapper: failures raise, as everywhere
else in this worker (no silent fallbacks).
"""

from typing import Any, Dict, List, Tuple

import numpy as np

from .mask_prep import keeper_guard_mask


def removal_touches_keeper(
    persons: List[Dict[str, Any]],
    instance_masks: List[np.ndarray],
    remove_ids: set,
) -> bool:
    """True when any removed person's raw mask touches any keeper's
    guard zone (keeper masks dilated by KEEPER_GUARD_PX)."""
    if not remove_ids or not instance_masks:
        return False
    guard = keeper_guard_mask(persons, instance_masks, remove_ids)
    if not guard.any():
        return False
    index = {p["id"]: i for i, p in enumerate(persons)}
    for pid in remove_ids:
        i = index.get(pid)
        if i is None or i >= len(instance_masks):
            continue
        m = np.asarray(instance_masks[i]) > 0
        if m.shape == guard.shape and bool(np.any(m & guard)):
            return True
    return False


def decide_engine(removal_count: int, overlap: bool) -> Tuple[str, str]:
    """The owner's rule. Returns (engine, routing_reason)."""
    if removal_count < 3:
        return "rorem", "r<3"
    if overlap and removal_count < 8:
        return "rorem", "overlap+r<8"
    return "mat", "default_mat"


class FallbackInpainter:
    """RORem in front, MAT behind — for engine="auto" jobs only.

    The first RORem exception flips the wrapper to MAT for the rest
    of the job (a half-broken GPU model must not be retried crop
    after crop) and sets fell_back, which the pipeline reads after
    the job to stamp the meta. Successful RORem crops before the
    failure stand — the job completes, honestly labelled.
    """

    def __init__(self, primary, fallback):
        self.primary = primary
        self.fallback = fallback
        self.fell_back = False
        self.error: str = ""

    @property
    def fallback_used(self) -> bool:
        # Read by the pipeline's fallbacks bookkeeping, which checks
        # the ACTIVE inpainter — a RORem->MAT engine fallback is a
        # routing event (in the routing meta), not a stage fallback.
        return False

    def inpaint_crop(self, image_crop: np.ndarray,
                     mask_crop: np.ndarray) -> np.ndarray:
        if self.fell_back:
            return self.fallback.inpaint_crop(image_crop, mask_crop)
        try:
            return self.primary.inpaint_crop(image_crop, mask_crop)
        except Exception as exc:  # noqa: BLE001 - the wrapper's whole job
            self.fell_back = True
            self.error = str(exc)[:300]
            try:
                import torch

                torch.cuda.empty_cache()
            except Exception:
                pass
            return self.fallback.inpaint_crop(image_crop, mask_crop)
