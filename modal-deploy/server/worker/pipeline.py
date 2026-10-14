"""
End-to-End Processing Pipeline — PeopleGone Phase 0
Implements §6.4 pipeline:
Detector (Apache-2.0) -> SAM 2.1 masks -> Keeper heuristic -> Mask prep & Shadows ->
LaMa crop inpaint -> Alpha composite -> Ghost check & retry -> Deliver native-res JPEG.
"""

import io
import time
from dataclasses import dataclass, field
from typing import Union, Optional, List, Dict, Any, Tuple
import numpy as np
from PIL import Image, ImageOps

from .detector import PersonDetector
from .segmentor import SamSegmentor
from .keeper import classify_keepers_and_removals
from .mask_prep import (
    prepare_individual_removal_masks,
    prepare_combined_removal_mask,
    dilate_mask
)
from .belongings import (
    merge_duplicate_items,
    person_halo,
    prepare_item_removal_mask,
    tier_belongings,
)
from .inpainter import LamaInpainter, get_crop_bounds, composite_with_feather
from .ghost_check import check_for_ghost_residuals, check_for_belongings_residuals

RUNPOD_16GB_PER_SEC_RATE = 0.00016  # $0.576 / hour

@dataclass
class PipelineConfig:
    detector_model: str = "PekingU/rtdetr_r50vd"
    sam_checkpoint: str = "facebook/sam2.1-hiera-tiny"
    lama_checkpoint: Optional[str] = None
    confidence_thresh: float = 0.35
    initial_dilation_factor: float = 0.02
    retry_dilation_factor: float = 0.05
    runpod_rate_per_sec: float = RUNPOD_16GB_PER_SEC_RATE
    jpeg_quality: int = 95

class PeopleGonePipeline:
    def __init__(self, config: Optional[PipelineConfig] = None):
        self.config = config or PipelineConfig()
        self.detector = PersonDetector(
            model_name=self.config.detector_model,
            confidence_threshold=self.config.confidence_thresh
        )
        self.segmentor = SamSegmentor(checkpoint=self.config.sam_checkpoint)
        self.inpainter = LamaInpainter(checkpoint_path=self.config.lama_checkpoint)

    def _analyse(
        self,
        orig_rgb: np.ndarray,
        keep: Optional[List[int]] = None,
        timings: Optional[Dict[str, float]] = None,
    ) -> Dict[str, Any]:
        """Detection + segmentation + belongings tiering (Phase A).

        Persons and belongings go through ONE segment_boxes() call:
        SAM's image encode is paid once per call (6.6-9.3 s CPU) while
        each extra box costs only a decode (0.1-0.5 s) — a second call
        for belongings would repay the full encode (investigation §6).

        Returns persons, keeper/remove id sets, per-person masks,
        tiered belongings (with their masks index-aligned).
        """
        timings = timings if timings is not None else {}

        t0 = time.perf_counter()
        persons = self.detector.detect_persons(orig_rgb)
        items = self.detector.detect_belongings(orig_rgb)
        timings["detection_ms"] = (time.perf_counter() - t0) * 1000.0

        keeper_ids: set = set()
        remove_ids: set = set()
        if persons:
            t0 = time.perf_counter()
            keeper_ids, remove_ids, _ = classify_keepers_and_removals(
                orig_rgb, persons, explicit_keep_ids=keep
            )
            timings["keeper_ms"] = (time.perf_counter() - t0) * 1000.0

        person_masks: List[np.ndarray] = []
        item_masks: List[np.ndarray] = []
        tiered: List[Dict[str, Any]] = []
        if persons or items:
            t0 = time.perf_counter()
            all_boxes = (
                [{"box": p["box"]} for p in persons]
                + [{"box": it["box"]} for it in items]
            )
            all_masks = self.segmentor.segment_boxes(orig_rgb, all_boxes)
            timings["segmentation_ms"] = (time.perf_counter() - t0) * 1000.0
            person_masks = all_masks[: len(persons)]
            item_masks = all_masks[len(persons):]

            # Adjustment 2: merge duplicate belongings detections by
            # mask IoU BEFORE tiering (ids of merged-away items simply
            # never surface; surviving ids are identical in /detect
            # and /process because both run this same code path).
            items, item_masks = merge_duplicate_items(items, item_masks)
            tiered = tier_belongings(
                persons, person_masks, keeper_ids, items, item_masks
            )

        return {
            "persons": persons,
            "keeper_ids": keeper_ids,
            "remove_ids": remove_ids,
            "person_masks": person_masks,
            "items": items,
            "item_masks": item_masks,
            "tiered": tiered,
        }

    def _build_removal_units(
        self,
        orig_rgb: np.ndarray,
        analysis: Dict[str, Any],
        remove_item_ids: set,
        detached_ids: set,
    ) -> Tuple[List[Dict[str, Any]], List[int], int]:
        """Builds the removal units for one confirmed job.

        Attached belongings are unioned into their owner's RAW mask
        BEFORE the standard fill/dilate/shadow prep, so the expanded
        mask is one region (FR-08). Detached belongings are simply
        never unioned, which is what protects them (X11). Ambiguous
        items become standalone units only when the user included
        them (remove_item_ids).

        Returns (units, belongings_removed_ids, items_removed) where
        items_removed counts ONLY the user-included ambiguous items
        (attached belongings are part of their person — X16, never
        itemised in the result summary).
        """
        persons = analysis["persons"]
        remove_ids = analysis["remove_ids"]
        tiered = analysis["tiered"]
        mask_by_item_id = {
            it["id"]: m
            for it, m in zip(analysis["items"], analysis["item_masks"])
        }

        units: List[Dict[str, Any]] = []
        belongings_removed_ids: List[int] = []

        if remove_ids:
            person_index = {p["id"]: i for i, p in enumerate(persons)}
            effective_masks = list(analysis["person_masks"])
            owners_with_items = set()
            for t in tiered:
                if t["tier"] != "attached" or t["id"] in detached_ids:
                    continue
                owner = t["person_id"]
                if owner in remove_ids:
                    idx = person_index[owner]
                    effective_masks[idx] = np.maximum(
                        effective_masks[idx], mask_by_item_id[t["id"]]
                    )
                    owners_with_items.add(owner)
                    belongings_removed_ids.append(t["id"])

            prepared = prepare_individual_removal_masks(
                orig_rgb, persons, effective_masks, remove_ids,
                dilation_factor=self.config.initial_dilation_factor
            )
            for item in prepared:
                units.append({
                    "mask": item["mask"],
                    "height": item["height"],
                    "kind": "person",
                    "has_items": item["person_id"] in owners_with_items,
                })

        items_removed = 0
        for t in tiered:
            if t["tier"] == "ambiguous" and t["id"] in remove_item_ids:
                units.append({
                    "mask": prepare_item_removal_mask(
                        mask_by_item_id[t["id"]], t["box"]
                    ),
                    "height": max(1, t["box"][3] - t["box"][1]),
                    "kind": "item",
                    "has_items": True,
                })
                belongings_removed_ids.append(t["id"])
                items_removed += 1

        return units, belongings_removed_ids, items_removed

    @staticmethod
    def _format_belongings(tiered: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Contract v3 belongings entries (additive over v2). The
        detected class travels as `detected_class` — a display hint,
        not a label of record (investigation adjustment 3)."""
        return [
            {
                "id": t["id"],
                "detected_class": t["detected_class"],
                "box": [int(b) for b in t["box"]],
                "score": float(t["score"]),
                "tier": t["tier"],
                "person_id": t["person_id"],
            }
            for t in tiered
        ]

    def _get_fallbacks_used(self) -> List[str]:
        fallbacks = []
        if getattr(self.detector, "fallback_used", False):
            fallbacks.append("detector")
        if getattr(self.segmentor, "fallback_used", False):
            fallbacks.append("segmentor")
        if getattr(self.inpainter, "fallback_used", False):
            fallbacks.append("inpainter")
        return fallbacks

    def process(
        self,
        photo: Union[str, bytes, np.ndarray, Image.Image],
        keep: Optional[List[int]] = None,
        remove_item_ids: Optional[List[int]] = None,
        detached_belonging_ids: Optional[List[int]] = None
    ) -> Tuple[bytes, Dict[str, Any]]:
        """Full clean. Confirm payload (Contract v3, additive over v2):
        keep = person ids to protect (as v2); remove_item_ids =
        AMBIGUOUS belongings the user chose to remove; detached_
        belonging_ids = ATTACHED belongings the user detached from
        their person (protected even when the person is removed).
        Attached belongings of removed persons are removed with their
        person by default (FR-08); attached belongings of keepers and
        detached belongings are never in any removal mask (X11).
        """
        t_start = time.perf_counter()
        timings = {}

        # 1. Load & EXIF orient image
        t0 = time.perf_counter()
        orig_pil = self._load_image(photo)
        orig_rgb = np.array(orig_pil)
        h, w = orig_rgb.shape[:2]
        timings["load_ms"] = (time.perf_counter() - t0) * 1000.0

        # 2-4. Detection + segmentation + keeper + belongings tiering
        analysis = self._analyse(orig_rgb, keep=keep, timings=timings)
        persons = analysis["persons"]
        keeper_ids = analysis["keeper_ids"]
        remove_ids = analysis["remove_ids"]
        tiered = analysis["tiered"]

        remove_item_ids = set(remove_item_ids or [])
        detached_ids = set(detached_belonging_ids or [])

        # Only ambiguous items the user explicitly included are removed
        # standalone; ids not present in this analysis are ignored (a
        # stale client must never invent a removal).
        included_items = [
            t for t in tiered
            if t["tier"] == "ambiguous" and t["id"] in remove_item_ids
        ]
        honoured_detached = sorted(
            t["id"] for t in tiered
            if t["tier"] == "attached" and t["id"] in detached_ids
        )

        def _meta(crops_inpainted: int, ghost_fired: bool, retry_count: int,
                  belongings_removed_ids: List[int], items_removed: int,
                  total_time_s: float) -> Dict[str, Any]:
            return {
                "contract_version": 3,
                "input_dimensions": [w, h],
                "output_dimensions": [w, h],
                "persons_detected": len(persons),
                "keeper_ids": sorted(list(keeper_ids)),
                "removed_ids": sorted(list(remove_ids)),
                "persons": [
                    {
                        "id": p["id"],
                        "box": [int(b) for b in p["box"]],
                        "score": float(p.get("score", 1.0)),
                        "is_keeper": p["id"] in keeper_ids,
                    }
                    for p in persons
                ],
                "belongings": self._format_belongings(tiered),
                "belongings_removed_ids": sorted(belongings_removed_ids),
                "belongings_detached_ids": honoured_detached,
                "items_removed": items_removed,
                "crops_inpainted": crops_inpainted,
                "timings_ms": timings,
                "total_seconds": round(total_time_s, 4),
                "total_gpu_seconds": round(total_time_s, 4),
                "cost_estimate_usd": round(total_time_s * self.config.runpod_rate_per_sec, 6),
                "ghost_check_fired": ghost_fired,
                "retry_count": retry_count,
                "fallbacks_used": self._get_fallbacks_used(),
                "model_versions": self._get_model_versions()
            }

        if not remove_ids and not included_items:
            total_time_s = time.perf_counter() - t_start
            timings["total_e2e_ms"] = total_time_s * 1000.0
            return self._encode_jpeg(orig_pil), _meta(
                0, False, 0, [], 0, total_time_s
            )

        # 5. Mask Preparation — removal units (see _build_removal_units)
        t0 = time.perf_counter()
        units, belongings_removed_ids, items_removed = (
            self._build_removal_units(
                orig_rgb, analysis, remove_item_ids, detached_ids
            )
        )
        timings["mask_prep_ms"] = (time.perf_counter() - t0) * 1000.0

        # 6. Inpainting on Native-Resolution Crops per removal unit
        t0 = time.perf_counter()
        composited = orig_rgb.copy()
        crops_inpainted = 0
        inpaint_crop_records = []

        for unit in units:
            m = unit["mask"]
            crop_bounds = get_crop_bounds(m)
            if crop_bounds is None:
                continue

            cx1, cy1, cx2, cy2 = crop_bounds
            image_crop = composited[cy1:cy2, cx1:cx2]
            mask_crop = m[cy1:cy2, cx1:cx2]

            inpainted_crop = self.inpainter.inpaint_crop(image_crop, mask_crop)
            composited = composite_with_feather(
                composited, inpainted_crop, mask_crop, crop_bounds, feather_px=4
            )
            crops_inpainted += 1
            inpaint_crop_records.append({
                "crop_bounds": crop_bounds,
                "item": unit
            })

        timings["inpaint_ms"] = (time.perf_counter() - t0) * 1000.0

        # 7. Second-pass Ghost Check on final composite. Person crops
        # are checked for person residuals (as before); any crop that
        # carried belongings is ALSO checked for belongings residuals
        # (Phase A) — a surviving item retries like a surviving person.
        t0 = time.perf_counter()
        ghost_fired = False
        ghost_affected_records = []

        for rec in inpaint_crop_records:
            cb = rec["crop_bounds"]
            unit = rec["item"]
            fired = False
            if unit["kind"] == "person":
                fired_person, _ = check_for_ghost_residuals(
                    composited, cb, self.detector
                )
                fired = fired or fired_person
            if unit["has_items"]:
                fired_item, _ = check_for_belongings_residuals(
                    composited, cb, self.detector
                )
                fired = fired or fired_item
            if fired:
                ghost_fired = True
                ghost_affected_records.append(rec)

        retry_count = 0
        if ghost_fired:
            retry_count = 1
            for rec in ghost_affected_records:
                cb = rec["crop_bounds"]
                item = rec["item"]
                cx1, cy1, cx2, cy2 = cb

                # Re-dilate using configured retry_dilation_factor relative to unit height
                bh = item["height"]
                retry_dilation_px = max(12, int(bh * self.config.retry_dilation_factor))
                dilated_retry_mask = dilate_mask(item["mask"], retry_dilation_px)

                image_crop = composited[cy1:cy2, cx1:cx2]
                mask_crop_retry = dilated_retry_mask[cy1:cy2, cx1:cx2]

                inpainted_retry = self.inpainter.inpaint_crop(image_crop, mask_crop_retry)
                composited = composite_with_feather(
                    composited, inpainted_retry, mask_crop_retry, cb, feather_px=6
                )

        timings["ghost_check_ms"] = (time.perf_counter() - t0) * 1000.0

        # 8. Final Delivery Encode
        total_time_s = time.perf_counter() - t_start
        timings["total_e2e_ms"] = total_time_s * 1000.0

        res_pil = Image.fromarray(composited)
        output_bytes = self._encode_jpeg(res_pil)

        return output_bytes, _meta(
            crops_inpainted, ghost_fired, retry_count,
            belongings_removed_ids, items_removed, total_time_s
        )

    def touchup(
        self,
        photo_bytes: bytes,
        mask_png_bytes: bytes,
    ) -> Tuple[bytes, Dict[str, Any]]:
        """Brush-fix touchup (FR-09, §6.4 composite pattern).

        Inpaints ONLY the crop around the user-painted mask region and
        composites it back onto the untouched original with feathering,
        so pixels outside the mask region are never modified before the
        final JPEG encode. Mask convention matches the rest of the
        pipeline: a uint8 mask where >0 (255) marks the hole to fill;
        the incoming PNG mask is thresholded at >127.
        """
        t_start = time.perf_counter()
        orig_pil = self._load_image(photo_bytes)
        orig_rgb = np.array(orig_pil)
        h, w = orig_rgb.shape[:2]

        meta: Dict[str, Any] = {
            "input_dimensions": [w, h],
            "output_dimensions": [w, h],
            "mask_resized": False,
        }

        mask_pil = Image.open(io.BytesIO(mask_png_bytes)).convert("L")
        if mask_pil.size != (w, h):
            mask_pil = mask_pil.resize((w, h), Image.NEAREST)
            meta["mask_resized"] = True
        mask_np = np.array(mask_pil)

        hole = mask_np > 127
        meta["mask_area_px"] = int(hole.sum())
        hole_mask_u8 = hole.astype(np.uint8) * 255

        bounds = get_crop_bounds(hole_mask_u8)
        if bounds is None:
            meta["touched"] = False
            meta["total_seconds"] = round(time.perf_counter() - t_start, 4)
            return self._encode_jpeg(orig_pil), meta

        cx1, cy1, cx2, cy2 = bounds
        image_crop = orig_rgb[cy1:cy2, cx1:cx2]
        mask_crop = hole_mask_u8[cy1:cy2, cx1:cx2]

        filled = self.inpainter.inpaint_crop(image_crop, mask_crop)
        composited = composite_with_feather(
            orig_rgb, filled, mask_crop, bounds, feather_px=4
        )

        meta["touched"] = True
        meta["crop_bounds"] = [int(b) for b in bounds]
        meta["total_seconds"] = round(time.perf_counter() - t_start, 4)
        return self._encode_jpeg(Image.fromarray(composited)), meta

    def detect(
        self,
        photo: Union[str, bytes, np.ndarray, Image.Image],
    ) -> Dict[str, Any]:
        """Runs detection (Stage A) + keeper heuristic + belongings
        tiering (Phase A) without inpainting. Tiering needs SAM masks,
        so /detect now pays the one SAM image encode (~7-9 s CPU); the
        v2 person fields are byte-identical to before, and belongings
        arrive as the additive v3 `belongings` list."""
        orig_pil = self._load_image(photo)
        orig_rgb = np.array(orig_pil)
        h, w = orig_rgb.shape[:2]

        analysis = self._analyse(orig_rgb, keep=None)
        persons = analysis["persons"]
        keeper_ids = analysis["keeper_ids"]
        remove_ids = analysis["remove_ids"]

        formatted_persons = [
            {
                "id": p["id"],
                "box": [int(b) for b in p["box"]],
                "score": float(p.get("score", 1.0)),
                "is_keeper": p["id"] in keeper_ids,
            }
            for p in persons
        ]

        return {
            "ok": True,
            "contract_version": 3,
            "input_dimensions": [w, h],
            "persons_detected": len(persons),
            "keeper_ids": sorted(list(keeper_ids)),
            "removed_ids": sorted(list(remove_ids)),
            "persons": formatted_persons,
            "belongings": self._format_belongings(analysis["tiered"]),
        }

    def _load_image(self, photo: Union[str, bytes, np.ndarray, Image.Image]) -> Image.Image:
        if isinstance(photo, Image.Image):
            pil_img = photo
        elif isinstance(photo, np.ndarray):
            pil_img = Image.fromarray(photo)
        elif isinstance(photo, bytes):
            pil_img = Image.open(io.BytesIO(photo))
        elif isinstance(photo, str):
            pil_img = Image.open(photo)
        else:
            raise ValueError(f"Unsupported photo type: {type(photo)}")

        pil_img = ImageOps.exif_transpose(pil_img)
        if pil_img.mode != "RGB":
            pil_img = pil_img.convert("RGB")
        return pil_img

    def _encode_jpeg(self, img_pil: Image.Image) -> bytes:
        buf = io.BytesIO()
        img_pil.save(buf, format="JPEG", quality=self.config.jpeg_quality)
        return buf.getvalue()

    def _get_model_versions(self) -> Dict[str, str]:
        return {
            "detector": self.config.detector_model,
            "segmentor": self.config.sam_checkpoint,
            "inpainter": "big-lama-v1",
            "pipeline": "peoplegone-v1-phase0"
        }

_pipeline_instance = None

def process(
    photo: Union[str, bytes, np.ndarray, Image.Image],
    keep: Optional[List[int]] = None,
    remove_item_ids: Optional[List[int]] = None,
    detached_belonging_ids: Optional[List[int]] = None,
    config: Optional[PipelineConfig] = None
) -> Tuple[bytes, Dict[str, Any]]:
    global _pipeline_instance
    if _pipeline_instance is None or config is not None:
        _pipeline_instance = PeopleGonePipeline(config)
    return _pipeline_instance.process(
        photo, keep=keep,
        remove_item_ids=remove_item_ids,
        detached_belonging_ids=detached_belonging_ids,
    )
