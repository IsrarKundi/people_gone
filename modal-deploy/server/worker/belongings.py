"""
Belongings Association Module — PeopleGone Phase A (FR-08)
Decides which detected belongings-class object (backpack, handbag,
suitcase, umbrella) belongs to which detected person, using mask
geometry only. Measured in docs/architecture/phase-a-investigation.md:
100% auto-attach precision and ZERO false attachments of a keeper's
belonging to a removed person across 16 items / 11 photos, with the
adjustments below applied.

Rules (owner-amended 2026-10-14; investigation adjustments 1-2):
- A person's HALO is their hole-filled SAM mask dilated by the same
  formula mask prep already uses: max(8, int(0.02 * box height)) px.
- A halo touch COUNTS only above a de-minimis bar:
  overlap >= max(100 px, 5% of the item's largest halo overlap).
  Graze contacts (measured as small as 56 px on a clear item) do not
  count. (Adjustment 1.)
- AUTO-ATTACH requires exactly ONE counted touch. Touching two
  people's halos above the bar is AMBIGUOUS by construction; touching
  none is AMBIGUOUS. Mere proximity never attaches.
- KEEPER VETO (before any attachment to a removed person): if the
  candidate owner is marked for removal and the item's mask touches a
  keeper's own (undilated) mask at all, or a keeper's halo overlap
  reaches half the candidate owner's halo overlap, the item is
  AMBIGUOUS instead. Ambiguity always resolves toward the keeper.
- Duplicate belongings detections are merged by mask IoU BEFORE
  tiering (the detector fires some items twice, sometimes under two
  different classes). (Adjustment 2.)
- The detected class is carried through as `detected_class` — a hint
  for display, never a fact the logic depends on. (Adjustment 3.)

Ambiguous items are the user's decision (design X10): they surface as
object chips, default Keep, and are removed only when the user
includes them in the confirm payload (remove_item_ids).
"""

from typing import List, Dict, Any, Optional, Set
import numpy as np

from .mask_prep import fill_mask_holes, dilate_mask


def prepare_item_removal_mask(item_mask: np.ndarray, item_box: List[int]) -> np.ndarray:
    """Removal mask for a standalone item (a user-included ambiguous
    belonging): hole fill + the pipeline's standard dilation,
    max(8, 2% of the item's box height) px. No shadow expansion —
    that heuristic is person-specific (it searches below a person's
    feet); an included item is filled on its own geometry."""
    filled = fill_mask_holes(item_mask)
    bh = max(1, item_box[3] - item_box[1])
    dilation_px = max(8, int(bh * 0.02))
    return dilate_mask(filled, dilation_px)

DE_MINIMIS_FLOOR_PX = 100
DE_MINIMIS_FRACTION = 0.05
MASK_DEDUPE_IOU_THRESHOLD = 0.5
KEEPER_VETO_HALO_FRACTION = 0.5


def person_halo(person_mask: np.ndarray, person_box: List[int]) -> np.ndarray:
    """Hole-filled person mask dilated by the pipeline's own formula
    (mask_prep.prepare_individual_removal_masks): max(8, 2% of the
    person's box height) px with the ellipse kernel."""
    filled = fill_mask_holes(person_mask)
    bh = max(1, person_box[3] - person_box[1])
    dilation_px = max(8, int(bh * 0.02))
    return dilate_mask(filled, dilation_px)


def _mask_iou(mask_a: np.ndarray, mask_b: np.ndarray) -> float:
    a = mask_a > 0
    b = mask_b > 0
    inter = int(np.logical_and(a, b).sum())
    union = int(np.logical_or(a, b).sum())
    return inter / union if union > 0 else 0.0


def merge_duplicate_items(
    items: List[Dict[str, Any]],
    item_masks: List[np.ndarray],
    iou_threshold: float = MASK_DEDUPE_IOU_THRESHOLD,
) -> "tuple[List[Dict[str, Any]], List[np.ndarray]]":
    """Merges belongings detections that fired twice on one physical
    item (mask IoU >= threshold). The higher-score detection's entry
    (class hint + box + score) wins; the kept mask is the UNION of the
    merged masks so tiering sees the whole item. Order is stable:
    the first occurrence's position is kept."""
    kept_items: List[Dict[str, Any]] = []
    kept_masks: List[np.ndarray] = []
    for item, mask in zip(items, item_masks):
        merged = False
        for idx in range(len(kept_items)):
            if _mask_iou(mask, kept_masks[idx]) >= iou_threshold:
                union_mask = np.maximum(kept_masks[idx], mask)
                if item["score"] > kept_items[idx]["score"]:
                    kept_items[idx] = item
                kept_masks[idx] = union_mask
                merged = True
                break
        if not merged:
            kept_items.append(item)
            kept_masks.append(mask)
    return kept_items, kept_masks


def tier_belongings(
    persons: List[Dict[str, Any]],
    person_masks: List[np.ndarray],
    keeper_ids: Set[int],
    items: List[Dict[str, Any]],
    item_masks: List[np.ndarray],
) -> List[Dict[str, Any]]:
    """Classifies each belongings item as attached to exactly one
    person or ambiguous. Inputs must already be deduped/merged
    (detector dedupe for boxes, merge_duplicate_items for masks).

    persons / person_masks are index-aligned; keeper_ids is the set of
    person ids classified as keepers (everyone else is a removal).

    Returns one dict per item:
    {'id', 'detected_class', 'box', 'score',
     'tier': 'attached' | 'ambiguous',
     'person_id': int | None,         # owner when attached
     'owner_overlap_px': int}         # halo overlap with the owner
    """
    halos = [person_halo(mask, p["box"]) for p, mask in zip(persons, person_masks)]
    filled_person_masks = [fill_mask_holes(m) for m in person_masks]
    person_index = {p["id"]: i for i, p in enumerate(persons)}

    results: List[Dict[str, Any]] = []
    for item, item_mask in zip(items, item_masks):
        item_bool = item_mask > 0
        overlaps: Dict[int, int] = {}
        for person, halo in zip(persons, halos):
            overlap = int(np.logical_and(item_bool, halo > 0).sum())
            if overlap > 0:
                overlaps[person["id"]] = overlap

        entry: Dict[str, Any] = {
            "id": item["id"],
            "detected_class": item["label"],
            "box": [int(b) for b in item["box"]],
            "score": float(item["score"]),
            "tier": "ambiguous",
            "person_id": None,
            "owner_overlap_px": 0,
        }

        if overlaps:
            largest = max(overlaps.values())
            bar = max(DE_MINIMIS_FLOOR_PX, DE_MINIMIS_FRACTION * largest)
            counted = {pid: px for pid, px in overlaps.items() if px >= bar}
            if len(counted) == 1:
                owner_id, owner_px = next(iter(counted.items()))
                if owner_id not in keeper_ids and _keeper_veto(
                    item_bool, owner_px, keeper_ids, persons,
                    halos, filled_person_masks, person_index,
                ):
                    pass  # vetoed -> stays ambiguous
                else:
                    entry["tier"] = "attached"
                    entry["person_id"] = owner_id
                    entry["owner_overlap_px"] = owner_px
        results.append(entry)
    return results


def _keeper_veto(
    item_bool: np.ndarray,
    owner_overlap_px: int,
    keeper_ids: Set[int],
    persons: List[Dict[str, Any]],
    halos: List[np.ndarray],
    filled_person_masks: List[np.ndarray],
    person_index: Dict[int, int],
) -> bool:
    """True when a keeper's claim on the item is strong enough that
    attaching it to a removed person is unsafe:
    - the item's mask touches a keeper's own (undilated) mask at all, or
    - a keeper's halo overlap reaches KEEPER_VETO_HALO_FRACTION of the
      candidate owner's halo overlap.
    """
    for keeper_id in keeper_ids:
        idx = person_index.get(keeper_id)
        if idx is None:
            continue
        if int(np.logical_and(item_bool, filled_person_masks[idx] > 0).sum()) > 0:
            return True
        keeper_overlap = int(np.logical_and(item_bool, halos[idx] > 0).sum())
        if keeper_overlap >= KEEPER_VETO_HALO_FRACTION * owner_overlap_px:
            return True
    return False
