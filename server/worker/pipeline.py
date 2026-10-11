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
from .mask_prep import prepare_combined_removal_mask, dilate_mask
from .inpainter import LamaInpainter, get_crop_bounds, composite_with_feather
from .ghost_check import check_for_ghost_residuals

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

    def process(
        self,
        photo: Union[str, bytes, np.ndarray, Image.Image],
        keep: Optional[List[int]] = None
    ) -> Tuple[bytes, Dict[str, Any]]:
        t_start = time.perf_counter()
        timings = {}

        # 1. Load & EXIF orient image
        t0 = time.perf_counter()
        orig_pil = self._load_image(photo)
        orig_rgb = np.array(orig_pil)
        h, w = orig_rgb.shape[:2]
        timings["load_ms"] = (time.perf_counter() - t0) * 1000.0

        # 2. Stage A — Person Detection
        t0 = time.perf_counter()
        persons = self.detector.detect_persons(orig_rgb)
        timings["detection_ms"] = (time.perf_counter() - t0) * 1000.0

        if not persons:
            # No persons found
            total_time_s = time.perf_counter() - t_start
            return self._encode_jpeg(orig_pil), {
                "input_dimensions": [w, h],
                "output_dimensions": [w, h],
                "persons_detected": 0,
                "keeper_ids": [],
                "removed_ids": [],
                "timings_ms": timings,
                "total_gpu_seconds": round(total_time_s, 4),
                "cost_estimate_usd": round(total_time_s * self.config.runpod_rate_per_sec, 6),
                "ghost_check_fired": False,
                "retry_count": 0,
                "model_versions": self._get_model_versions()
            }

        # 3. Instance Segmentation (SAM 2.1)
        t0 = time.perf_counter()
        masks = self.segmentor.segment_boxes(orig_rgb, persons)
        timings["segmentation_ms"] = (time.perf_counter() - t0) * 1000.0

        # 4. Keeper Heuristic
        t0 = time.perf_counter()
        keeper_ids, remove_ids, scored_persons = classify_keepers_and_removals(
            orig_rgb, persons, explicit_keep_ids=keep
        )
        timings["keeper_ms"] = (time.perf_counter() - t0) * 1000.0

        if not remove_ids:
            # Only keepers detected
            total_time_s = time.perf_counter() - t_start
            return self._encode_jpeg(orig_pil), {
                "input_dimensions": [w, h],
                "output_dimensions": [w, h],
                "persons_detected": len(persons),
                "keeper_ids": sorted(list(keeper_ids)),
                "removed_ids": [],
                "timings_ms": timings,
                "total_gpu_seconds": round(total_time_s, 4),
                "cost_estimate_usd": round(total_time_s * self.config.runpod_rate_per_sec, 6),
                "ghost_check_fired": False,
                "retry_count": 0,
                "model_versions": self._get_model_versions()
            }

        # 5. Mask Preparation (Dilation + Shadows)
        t0 = time.perf_counter()
        combined_mask = prepare_combined_removal_mask(
            orig_rgb, persons, masks, remove_ids,
            dilation_factor=self.config.initial_dilation_factor
        )
        timings["mask_prep_ms"] = (time.perf_counter() - t0) * 1000.0

        # 6. Inpainting on Native-Resolution Crops
        t0 = time.perf_counter()
        crop_bounds = get_crop_bounds(combined_mask)
        if crop_bounds is None:
            crop_bounds = (0, 0, w, h)

        cx1, cy1, cx2, cy2 = crop_bounds
        image_crop = orig_rgb[cy1:cy2, cx1:cx2]
        mask_crop = combined_mask[cy1:cy2, cx1:cx2]

        inpainted_crop = self.inpainter.inpaint_crop(image_crop, mask_crop)
        composited = composite_with_feather(
            orig_rgb, inpainted_crop, mask_crop, crop_bounds, feather_px=4
        )
        timings["inpaint_ms"] = (time.perf_counter() - t0) * 1000.0

        # 7. Second-pass Ghost Check
        t0 = time.perf_counter()
        ghost_fired, residuals = check_for_ghost_residuals(
            composited, crop_bounds, self.detector
        )
        retry_count = 0

        # Automatic single retry with larger dilation if ghost detected
        if ghost_fired:
            retry_count = 1
            larger_mask = dilate_mask(combined_mask, dilation_px=16)
            mask_crop_retry = larger_mask[cy1:cy2, cx1:cx2]
            inpainted_retry = self.inpainter.inpaint_crop(image_crop, mask_crop_retry)
            composited = composite_with_feather(
                orig_rgb, inpainted_retry, mask_crop_retry, crop_bounds, feather_px=6
            )

        timings["ghost_check_ms"] = (time.perf_counter() - t0) * 1000.0

        # 8. Final Delivery Encode
        total_time_s = time.perf_counter() - t_start
        timings["total_e2e_ms"] = total_time_s * 1000.0

        res_pil = Image.fromarray(composited)
        output_bytes = self._encode_jpeg(res_pil)

        metadata = {
            "input_dimensions": [w, h],
            "output_dimensions": [w, h],
            "persons_detected": len(persons),
            "keeper_ids": sorted(list(keeper_ids)),
            "removed_ids": sorted(list(remove_ids)),
            "timings_ms": timings,
            "total_gpu_seconds": round(total_time_s, 4),
            "cost_estimate_usd": round(total_time_s * self.config.runpod_rate_per_sec, 6),
            "ghost_check_fired": ghost_fired,
            "retry_count": retry_count,
            "model_versions": self._get_model_versions()
        }

        return output_bytes, metadata

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
    config: Optional[PipelineConfig] = None
) -> Tuple[bytes, Dict[str, Any]]:
    global _pipeline_instance
    if _pipeline_instance is None or config is not None:
        _pipeline_instance = PeopleGonePipeline(config)
    return _pipeline_instance.process(photo, keep=keep)
