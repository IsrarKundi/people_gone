"""
Phase C — shadow cleanup v1: DIRECTIONAL shadow growth for mask prep.

Faithful production port of the investigated prototype
(phase-c-investigation/scripts/shadow_v1.py, frozen iteration 4).
Investigation + gate evidence: docs/architecture/phase-c-investigation.md.

Approach (removal-expansion-plan §4 Phase C):
1. Estimate light direction from ALL detected persons' observed
   shadow blobs (locally-dark, low-saturation pixels connected to a
   person, outside every person's mask). A blob is a VALID direction
   sample only if its mass sits at/below the person's feet line
   (modest allowance above for wall-climbing shadows) and it passes
   through the contact strip just below the feet: blobs centred high
   above the person, or merely touching a person's side, are scenery
   (shade masses, dark facades, tree lines) — earlier iterations
   showed they otherwise hijack the estimate. The photo-level
   direction is the area-weighted circular mean of valid samples,
   gated on agreement and on at least weak cast evidence; a lone
   sample is trusted only when it points clearly downward. No
   confident direction -> NO growth anywhere.
2. Per removed person, the growth direction is their OWN blob
   direction when they have a solid one (shadows are parallel in the
   world, not in the image — perspective makes each person's
   image-space direction differ), blended toward the photo-level
   direction; otherwise the photo direction alone.
3. Growth: locally-dark, low-saturation pixels inside a corridor
   swept from the person's lower-body mask slice along the growth
   direction as a fan of three constant-width sweeps (direction,
   +/- ~8 degrees; bounded length), restricted to the component
   connected to the person. The production below-feet heuristic is
   the FLOOR — v1 only ADDS.
4. Keeper veto (absolute): additions never enter the protected set
   = keeper halos UNION keepers' own observed shadow blobs.
   Additions per person are also area-capped (<= 3x the person's
   mask area, nearest-first along the direction) as a runaway
   safety valve.

No new models, no new dependencies (numpy + cv2, already worker deps).
"""
from typing import Dict, List, Optional, Tuple

import cv2
import numpy as np

from .mask_prep import (
    dilate_mask,
    expand_shadows,
    fill_mask_holes,
    keeper_guard_mask,
)

# Production thresholds (mask_prep.expand_shadows) — kept identical.
SHADOW_V_MAX = 130
SHADOW_S_MAX = 140

CONNECT_KERNEL = 5
CONNECT_ITERS = 3
EST_EXPAND_X = 0.6      # estimator search: box width fraction each side
EST_EXPAND_UP = 0.35    # estimator search: box height fraction above
EST_EXPAND_DOWN = 1.0   # estimator search: box height fraction below
MIN_BLOB_PX = 200
MIN_SAMPLE_LEN_FRAC = 0.08   # of person height, for a direction sample
STRONG_SAMPLE_LEN_FRAC = 0.25
MIN_AGREEMENT = 0.5          # weighted circular resultant length
MIN_MEDIAN_LEN_FRAC = 0.15   # photo-level cast evidence gate
BLOB_ABOVE_FEET_ALLOW = 0.35  # blob centroid may sit this far (x bh)
                              # above the feet line (wall-climbing)
RELATIVE_DARK_FRAC = 0.85    # growth candidates: V < frac x local V
MAX_GROW_LEN_FRAC = 2.5      # corridor length cap, x person height
LOWER_SLICE_FRAC = 0.40      # corridor sweeps the mask's bottom 40%
MAX_ADD_AREA_FRAC = 3.0      # additions cap, x person mask area


def shadow_candidates(image_rgb: np.ndarray) -> np.ndarray:
    """Boolean map of shadow-plausible pixels (production test)."""
    hsv = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2HSV)
    return (hsv[:, :, 2] < SHADOW_V_MAX) & (hsv[:, :, 1] < SHADOW_S_MAX)


def _relative_dark_pool(image_rgb, v_max, rel_frac):
    """Locally-dark, low-saturation pixels: dark relative to their
    surroundings (uniform shade masses and interiors are locally
    uniform and drop out; true cast shadows are locally dark)."""
    hsv = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2HSV)
    v = hsv[:, :, 2]
    k = max(15, int(0.015 * image_rgb.shape[1]) | 1)
    local_v = cv2.blur(v, (k, k)).astype(np.float32)
    return (
        (v < v_max)
        & (hsv[:, :, 1] < SHADOW_S_MAX)
        & (v.astype(np.float32) < rel_frac * local_v)
    )


def estimation_pool(image_rgb: np.ndarray) -> np.ndarray:
    """Pool the light-direction estimator reads. On bright ground
    (sand, sunlit tile) real shadows sit far above the production
    V<130 test — the investigation measured ZERO samples there with
    the production test — so estimation uses local darkness, gated
    harder."""
    return _relative_dark_pool(image_rgb, 200, 0.80)


def growth_candidates(image_rgb: np.ndarray) -> np.ndarray:
    """Pool growth may add: locally dark, low saturation. (The
    production V<130 test remains the FLOOR's test, unchanged; the
    growth pool is what the directional region is built from.)"""
    return _relative_dark_pool(image_rgb, 210, RELATIVE_DARK_FRAC)


def _components(bool_arr: np.ndarray):
    n, labels = cv2.connectedComponents(bool_arr.astype(np.uint8), connectivity=8)
    return n, labels


def observed_shadow_blob(
    candidates: np.ndarray,
    person_mask: np.ndarray,
    box,
    persons_union: np.ndarray,
) -> np.ndarray:
    """Shadow-candidate pixels connected to one person, searched in a
    generous region around the person's box (all directions — side
    shadows are the point), excluding every person's interior."""
    h, w = candidates.shape
    x1, y1, x2, y2 = [int(v) for v in box]
    bw = max(1, x2 - x1)
    bh = max(1, y2 - y1)
    rx1 = max(0, x1 - int(bw * EST_EXPAND_X))
    rx2 = min(w, x2 + int(bw * EST_EXPAND_X))
    ry1 = max(0, y1 - int(bh * EST_EXPAND_UP))
    ry2 = min(h, y2 + int(bh * EST_EXPAND_DOWN))
    if rx2 <= rx1 or ry2 <= ry1:
        return np.zeros_like(candidates)

    region = candidates[ry1:ry2, rx1:rx2] & ~persons_union[ry1:ry2, rx1:rx2]
    pmask = person_mask[ry1:ry2, rx1:rx2]
    kernel = cv2.getStructuringElement(
        cv2.MORPH_RECT, (CONNECT_KERNEL, CONNECT_KERNEL)
    )
    seed = cv2.dilate(pmask.astype(np.uint8), kernel, iterations=CONNECT_ITERS) > 0
    if not (region & seed).any():
        return np.zeros_like(candidates)
    n, labels = _components(region)
    keep_ids = np.unique(labels[region & seed])
    keep_ids = keep_ids[keep_ids != 0]
    blob = np.isin(labels, keep_ids)
    out = np.zeros_like(candidates)
    out[ry1:ry2, rx1:rx2] = blob
    return out


def _mask_anchor(person_mask: np.ndarray):
    """Bottom-centre anchor of a person mask (feet midpoint)."""
    ys, xs = np.nonzero(person_mask)
    if len(ys) == 0:
        return None
    y_max = ys.max()
    bottom = xs[ys >= y_max - max(2, int(0.02 * (y_max - ys.min() + 1)))]
    return float(bottom.mean()), float(y_max)


def collect_direction_samples(image_rgb, persons, masks_bool, candidates=None):
    """Per-person valid direction samples:
    {person_id: {"vec": unit (dx,dy), "len_frac": float, "blob": mask}}.
    Validity: blob big enough, long enough, passes the contact strip
    below the feet, and its centroid at or below
    (feet - BLOB_ABOVE_FEET_ALLOW x height)."""
    if candidates is None:
        candidates = shadow_candidates(image_rgb)
    persons_union = np.zeros(candidates.shape, dtype=bool)
    for m in masks_bool:
        persons_union |= m

    samples = {}
    H, W = candidates.shape
    for p, m in zip(persons, masks_bool):
        blob = observed_shadow_blob(candidates, m, p["box"], persons_union)
        anchor = _mask_anchor(m)
        if anchor is None:
            continue
        bh0 = max(1, int(p["box"][3]) - int(p["box"][1]))
        # Clip the blob to a disc around the feet anchor: parts of a
        # SHARED pool lying far away belong to other people and would
        # drag the centroid (a group's merged pool otherwise reads as
        # one sideways direction for everyone in it).
        r = 1.3 * bh0
        gx1 = max(0, int(anchor[0] - r)); gx2 = min(W, int(anchor[0] + r) + 1)
        gy1 = max(0, int(anchor[1] - r)); gy2 = min(H, int(anchor[1] + r) + 1)
        yy, xx = np.ogrid[gy1:gy2, gx1:gx2]
        disc = ((xx - anchor[0]) ** 2 + (yy - anchor[1]) ** 2 <= r * r)
        blob_win = blob[gy1:gy2, gx1:gx2] & disc
        blob = np.zeros_like(blob)
        blob[gy1:gy2, gx1:gx2] = blob_win
        area = int(blob.sum())
        if area < MIN_BLOB_PX:
            continue
        ys, xs = np.nonzero(blob)
        cx, cy = float(xs.mean()), float(ys.mean())
        bh = bh0
        if cy < anchor[1] - BLOB_ABOVE_FEET_ALLOW * bh:
            continue  # scenery above the person, not their shadow
        # Contact-strip rule: every real cast shadow emanates from
        # the feet and passes through the strip just below them.
        # Scenery blobs that merely touch a person's side or head
        # (tree lines, shade masses) do not.
        x1b, x2b = int(p["box"][0]), int(p["box"][2])
        strip_x1 = max(0, x1b - int(0.3 * (x2b - x1b)))
        strip_x2 = min(candidates.shape[1], x2b + int(0.3 * (x2b - x1b)))
        strip_y1 = int(anchor[1]) - 2
        strip_y2 = min(candidates.shape[0], int(anchor[1]) + int(0.15 * bh))
        if strip_y2 > strip_y1 and not blob[strip_y1:strip_y2, strip_x1:strip_x2].any():
            continue
        vec = np.array([cx - anchor[0], cy - anchor[1]], dtype=np.float64)
        length = float(np.hypot(*vec))
        if length < MIN_SAMPLE_LEN_FRAC * bh:
            continue
        samples[int(p["id"])] = {
            "vec": (float(vec[0] / length), float(vec[1] / length)),
            "len_frac": length / bh,
            "weight": float(area),
            "blob": blob,
        }
    return samples


def photo_direction(samples):
    """Area-weighted circular mean of valid samples + gate.
    Returns (unit vec or None, info)."""
    info = {"samples": len(samples), "agreement": 0.0, "median_len_frac": 0.0}
    if not samples:
        return None, info
    weights = np.array([s["weight"] for s in samples.values()])
    vecs = np.array([s["vec"] for s in samples.values()])
    resultant = (vecs * weights[:, None]).sum(axis=0) / weights.sum()
    agreement = float(np.hypot(*resultant))
    info["agreement"] = agreement
    info["median_len_frac"] = float(
        np.median([s["len_frac"] for s in samples.values()])
    )
    longest = max(s["len_frac"] for s in samples.values())
    if agreement < MIN_AGREEMENT:
        return None, info
    if longest < STRONG_SAMPLE_LEN_FRAC:
        return None, info
    # A lone sample is fragile evidence: investigation iterations
    # repeatedly showed a single scenery-connected blob pointing UP
    # while every genuine single-cast sample points clearly down.
    # Trust a lone sample only when it points clearly downward.
    if len(samples) == 1:
        only = next(iter(samples.values()))["vec"]
        if only[1] < 0.3:
            return None, info
    if info["median_len_frac"] < MIN_MEDIAN_LEN_FRAC and len(samples) < 3:
        return None, info
    direction = resultant / np.hypot(*resultant)
    return (float(direction[0]), float(direction[1])), info


def person_direction(person_id, samples, photo_dir):
    """Growth direction for one person: own solid sample blended
    toward the photo direction; own weak sample blended evenly;
    otherwise the photo direction."""
    s = samples.get(int(person_id))
    if photo_dir is None:
        return None
    if s is None:
        return photo_dir
    own = np.array(s["vec"], dtype=np.float64)
    g = np.array(photo_dir, dtype=np.float64)
    w_own = 2.0 if s["len_frac"] >= STRONG_SAMPLE_LEN_FRAC else 1.0
    blended = w_own * own + 1.0 * g
    n = float(np.hypot(*blended))
    if n == 0:
        return photo_dir
    return (float(blended[0] / n), float(blended[1] / n))


def _shift(arr: np.ndarray, dx: int, dy: int) -> np.ndarray:
    out = np.zeros_like(arr)
    h, w = arr.shape
    sx1, sx2 = max(0, -dx), min(w, w - dx)
    sy1, sy2 = max(0, -dy), min(h, h - dy)
    tx1, tx2 = max(0, dx), min(w, w + dx)
    ty1, ty2 = max(0, dy), min(h, h + dy)
    if sx2 > sx1 and sy2 > sy1:
        out[ty1:ty2, tx1:tx2] = arr[sy1:sy2, sx1:sx2]
    return out


def directional_additions(
    candidates: np.ndarray,
    dilated_mask_bool: np.ndarray,
    person_mask_bool: np.ndarray,
    box,
    direction,
    protected_bool: np.ndarray,
    persons_union: np.ndarray,
    max_len_frac: float = MAX_GROW_LEN_FRAC,
) -> np.ndarray:
    """Growth-pool pixels inside the corridor swept from the person's
    LOWER-body slice along `direction`, connected to the person,
    minus the protected set (keeper veto) and person bodies;
    area-capped nearest-first along the direction.

    The corridor is a fan of three constant-width sweeps (direction,
    +/- ~8 degrees) — equivalent widening to per-step dilation at a
    fraction of the cost — and all work happens in a window around
    the person for speed.
    """
    H, W = candidates.shape
    bh = max(1, int(box[3]) - int(box[1]))
    bw = max(1, int(box[2]) - int(box[0]))
    max_len = int(max_len_frac * bh)

    # Window: the person's box grown by max_len along the direction
    # plus margin, clipped to the frame.
    wx1 = max(0, int(box[0]) - int(max_len * max(0.0, -direction[0])) - bw // 2)
    wx2 = min(W, int(box[2]) + int(max_len * max(0.0, direction[0])) + bw // 2)
    wy1 = max(0, int(box[1]) - int(max_len * max(0.0, -direction[1])) - bh // 4)
    wy2 = min(H, int(box[3]) + int(max_len * max(0.0, direction[1])) + bh // 4)
    if wx2 <= wx1 or wy2 <= wy1:
        return np.zeros_like(candidates)

    dil_w = dilated_mask_bool[wy1:wy2, wx1:wx2]
    ys, xs = np.nonzero(dil_w)
    if len(ys) == 0:
        return np.zeros_like(candidates)
    y_top = ys.min()
    slice_from = y_top + int((1.0 - LOWER_SLICE_FRAC) * (ys.max() - y_top + 1))
    base = dil_w.copy()
    base[:slice_from, :] = False
    if not base.any():
        base = dil_w

    step = max(4, bh // 20)
    corridor = base.copy()
    theta = np.arctan2(direction[1], direction[0])
    for dth in (0.0, 0.14, -0.14):
        d = (float(np.cos(theta + dth)), float(np.sin(theta + dth)))
        s = step
        while s <= max_len:
            dx = int(round(d[0] * s))
            dy = int(round(d[1] * s))
            if dx == 0 and dy == 0:
                s += step
                continue
            corridor |= _shift(base, dx, dy)
            s += step

    region = (
        candidates[wy1:wy2, wx1:wx2]
        & corridor
        & ~persons_union[wy1:wy2, wx1:wx2]
    )
    kernel = cv2.getStructuringElement(
        cv2.MORPH_RECT, (CONNECT_KERNEL, CONNECT_KERNEL)
    )
    seed = (
        cv2.dilate(dil_w.astype(np.uint8), kernel, iterations=CONNECT_ITERS) > 0
    )
    additions_full = np.zeros_like(candidates)
    if not (region & seed).any():
        return additions_full
    n, labels = _components(region)
    keep_ids = np.unique(labels[region & seed])
    keep_ids = keep_ids[keep_ids != 0]
    grown = np.isin(labels, keep_ids)
    additions = (
        grown
        & ~dil_w
        & ~protected_bool[wy1:wy2, wx1:wx2]
    )

    # Area cap (runaway valve): keep pixels nearest along direction.
    cap = int(MAX_ADD_AREA_FRAC * max(1, int(person_mask_bool.sum())))
    if int(additions.sum()) > cap:
        anchor = _mask_anchor(person_mask_bool)
        ys_a, xs_a = np.nonzero(additions)
        gxs = xs_a + wx1
        gys = ys_a + wy1
        t = (gxs - anchor[0]) * direction[0] + (gys - anchor[1]) * direction[1]
        order = np.argsort(t)
        keep_idx = order[:cap]
        capped = np.zeros_like(additions)
        capped[ys_a[keep_idx], xs_a[keep_idx]] = True
        additions = capped
    additions_full[wy1:wy2, wx1:wx2] = additions
    return additions_full


def prepare_masks_v1(
    image_rgb: np.ndarray,
    persons: List[Dict],
    instance_masks: List[np.ndarray],
    remove_ids,
    dilation_factor: float = 0.02,
) -> List[Dict]:
    """v1 mask prep. Same inputs/outputs as
    mask_prep.prepare_individual_removal_masks (instance_masks is
    the list parallel to persons, as the pipeline passes it).

    Floor = the production path, unchanged (fill -> dilate ->
    expand_shadows). v1 adds directional growth for removed persons
    when a reliable light direction exists.
    """
    masks_bool = [np.asarray(m).astype(bool) for m in instance_masks]
    est_pool = estimation_pool(image_rgb)
    grow_pool = growth_candidates(image_rgb)
    persons_union = np.zeros(est_pool.shape, dtype=bool)
    for m in masks_bool:
        persons_union |= m

    samples = collect_direction_samples(image_rgb, persons, masks_bool, est_pool)
    direction, _est_info = photo_direction(samples)

    remove_set = set(remove_ids)
    keeper_ids = [p["id"] for p in persons if p["id"] not in remove_set]
    # Protected set: keeper halos UNION keepers' own shadow blobs
    # (design X12/X13: the keeper's shadow is protected absolutely).
    protected = np.zeros(est_pool.shape, dtype=bool)
    mask_by_id = {p["id"]: m for p, m in zip(persons, masks_bool)}
    for p in persons:
        if p["id"] in keeper_ids:
            bh = max(1, int(p["box"][3]) - int(p["box"][1]))
            dpx = max(8, int(bh * dilation_factor))
            halo = dilate_mask(
                fill_mask_holes((mask_by_id[p["id"]] * 255).astype(np.uint8)), dpx
            ) > 0
            protected |= halo
            s = samples.get(int(p["id"]))
            if s is not None:
                protected |= s["blob"]
            else:
                protected |= observed_shadow_blob(
                    est_pool, mask_by_id[p["id"]], p["box"], persons_union
                )

    # Keeper protection (overlap fix, 2026-10-20): the protected set
    # above vetoes only the shadow GROWTH. The base mask itself —
    # raw SAM mask, hole fill, dilation, floor shadow — was never
    # clipped against the keeper, so a removed person standing
    # behind the keeper swallowed thin keeper structures (fingers)
    # that hang in front of them. Fill holes on the RAW mask first
    # (hole filling also completes an under-segmented removed
    # person whose SAM mask encloses their own torso — carving
    # before filling opened that enclosure on the owner's photo and
    # left a survivor torso, Phase 2 diagnostic), then carve the
    # keeper (+ guard) out of the filled mask and subtract it
    # again from the finished mask.
    guard = keeper_guard_mask(persons, instance_masks, remove_set)

    results = []
    for p, m in zip(persons, masks_bool):
        if p["id"] not in remove_set:
            continue
        filled = fill_mask_holes((m * 255).astype(np.uint8))
        if guard.any():
            filled[guard] = 0
        bh = max(1, int(p["box"][3]) - int(p["box"][1]))
        dpx = max(8, int(bh * dilation_factor))
        dilated = dilate_mask(filled, dpx)
        floor = expand_shadows(image_rgb, dilated, p["box"])
        final = floor.copy()
        gdir = person_direction(p["id"], samples, direction)
        if gdir is not None:
            adds = directional_additions(
                grow_pool, dilated > 0, m, p["box"], gdir,
                protected, persons_union,
            )
            new_px = adds & ~(floor > 0)
            final[new_px] = 255
        if guard.any():
            final[guard] = 0
        results.append(
            {"person_id": p["id"], "box": p["box"], "mask": final, "height": bh}
        )
    return results
