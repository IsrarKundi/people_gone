"""
Person Detector Module — PeopleGone Phase 0
Uses permissive Apache-2.0 checkpoints (RT-DETR or DETR) via Hugging Face.
Ultralytics YOLO is strictly forbidden.
"""

import os
from typing import List, Dict, Any, Optional
import numpy as np

# COCO classes treated as a person's belongings (Phase A, FR-08).
# The detected class is a HINT, not a label of record: the detector
# mislabels these classes against each other (handbag vs suitcase vs
# backpack — measured 3/16 in the Phase A investigation), so callers
# must not build logic that depends on the exact class, only on the
# geometry. See docs/architecture/phase-a-investigation.md §5.5.
BELONGINGS_LABELS = {"backpack", "handbag", "suitcase", "umbrella"}

# Two detections of the SAME kind whose boxes overlap at or above this
# IoU are one physical object fired twice (RT-DETR double-fires: the
# investigation found a person returned twice at ~90% box overlap).
# Duplicates are merged (highest score wins) BEFORE ids are assigned,
# so ids stay stable between /detect and /process on the same photo.
DEDUPE_IOU_THRESHOLD = 0.85


def _box_iou(box_a: List[int], box_b: List[int]) -> float:
    x_a = max(box_a[0], box_b[0])
    y_a = max(box_a[1], box_b[1])
    x_b = min(box_a[2], box_b[2])
    y_b = min(box_a[3], box_b[3])
    inter = max(0, x_b - x_a) * max(0, y_b - y_a)
    area_a = (box_a[2] - box_a[0]) * (box_a[3] - box_a[1])
    area_b = (box_b[2] - box_b[0]) * (box_b[3] - box_b[1])
    union = float(area_a + area_b - inter)
    return inter / union if union > 0 else 0.0


def dedupe_detections(
    detections: List[Dict[str, Any]],
    iou_threshold: float = DEDUPE_IOU_THRESHOLD,
) -> List[Dict[str, Any]]:
    """Merges duplicate detections (same physical object fired twice).

    Deterministic: the first occurrence's position is kept; when a
    later duplicate scores higher it replaces the kept entry in place,
    so the output order (and therefore id assignment) is stable.
    """
    kept: List[Dict[str, Any]] = []
    for det in detections:
        merged = False
        for idx, existing in enumerate(kept):
            if _box_iou(det["box"], existing["box"]) >= iou_threshold:
                if det["score"] > existing["score"]:
                    kept[idx] = det
                merged = True
                break
        if not merged:
            kept.append(det)
    return kept


class PersonDetector:
    def __init__(
        self,
        model_name: str = "PekingU/rtdetr_r50vd",
        confidence_threshold: float = 0.35,
        device: Optional[str] = None
    ):
        self.model_name = model_name
        self.confidence_threshold = confidence_threshold
        self.device = device
        self._model = None
        self._processor = None
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
            from transformers import AutoImageProcessor, AutoModelForObjectDetection

            if self.device is None:
                self.device = "cuda" if torch.cuda.is_available() else "cpu"

            # RT-DETR or DETR (both Apache 2.0)
            self._processor = AutoImageProcessor.from_pretrained(self.model_name)
            self._model = AutoModelForObjectDetection.from_pretrained(self.model_name).to(self.device)
            self._model.eval()
        except Exception as e:
            self._load_error = str(e)
            self._model = None
            self._processor = None
            if not self.allow_fallbacks:
                raise RuntimeError(
                    f"Stage 'detector' failed to load model '{self.model_name}': {e}. "
                    "Silent fallbacks are disabled. Set PG_ALLOW_FALLBACKS=1 only for offline development."
                ) from e

    def _raw_detections(self, image_np: np.ndarray) -> Optional[List[Dict[str, Any]]]:
        """Runs the detector once and returns EVERY detection above the
        confidence threshold as {'box', 'score', 'label'} (no id yet),
        or None when the model is unavailable and fallbacks are enabled
        (the caller then decides its fallback behaviour). Raises when
        fallbacks are disabled, exactly as before."""
        h, w = image_np.shape[:2]
        self._lazy_init()

        if self._model is not None and self._processor is not None:
            try:
                import torch
                from PIL import Image

                pil_img = Image.fromarray(image_np)
                inputs = self._processor(images=pil_img, return_tensors="pt").to(self.device)

                with torch.no_grad():
                    outputs = self._model(**inputs)

                target_sizes = torch.tensor([[h, w]]).to(self.device)
                results = self._processor.post_process_object_detection(
                    outputs, target_sizes=target_sizes, threshold=self.confidence_threshold
                )[0]

                detections = []
                for score, label_id, box in zip(results["scores"], results["labels"], results["boxes"]):
                    label_name = self._model.config.id2label.get(label_id.item(), "").lower()
                    b = box.tolist()
                    x1 = max(0, int(round(b[0])))
                    y1 = max(0, int(round(b[1])))
                    x2 = min(w, int(round(b[2])))
                    y2 = min(h, int(round(b[3])))
                    if x2 > x1 and y2 > y1:
                        detections.append({
                            "box": [x1, y1, x2, y2],
                            "score": float(score.item()),
                            "label": label_name,
                        })
                return detections
            except Exception as e:
                if not self.allow_fallbacks:
                    raise RuntimeError(
                        f"Stage 'detector' inference failed on '{self.model_name}': {e}."
                    ) from e

        # Fallback detector only if explicitly enabled
        if not self.allow_fallbacks:
            raise RuntimeError(
                f"Stage 'detector' model '{self.model_name}' is not initialized: {self._load_error}. "
                "Silent fallbacks are disabled. Set PG_ALLOW_FALLBACKS=1 only for offline development."
            )

        self.fallback_used = True
        return None

    def detect_persons(self, image_np: np.ndarray) -> List[Dict[str, Any]]:
        """
        Detects all persons in an RGB image.
        Returns a list of dicts:
        [{'id': int, 'box': [x1, y1, x2, y2], 'score': float, 'label': 'person'}]
        Duplicate person boxes are merged before ids are assigned
        (see dedupe_detections).
        """
        self.fallback_used = False
        raw = self._raw_detections(image_np)
        if raw is None:
            return self._heuristic_fallback(image_np)

        persons = [
            {"box": d["box"], "score": d["score"], "label": "person"}
            for d in raw
            if "person" in d["label"]
            and (d["box"][2] - d["box"][0]) > 10
            and (d["box"][3] - d["box"][1]) > 20
        ]
        persons = dedupe_detections(persons)
        for idx, person in enumerate(persons):
            person["id"] = idx
        return persons

    def detect_belongings(self, image_np: np.ndarray) -> List[Dict[str, Any]]:
        """
        Detects belongings-class objects (backpack, handbag, suitcase,
        umbrella — Phase A, FR-08) in the same detector pass family.
        Returns [{'id': int, 'box': [...], 'score': float,
        'label': <detected class — a HINT, see BELONGINGS_LABELS>}].
        Ids are the item ids the confirm payload refers to
        (remove_item_ids / detached_belonging_ids); they are assigned
        after dedupe so they are stable between /detect and /process.
        """
        self.fallback_used = False
        raw = self._raw_detections(image_np)
        if raw is None:
            # Fallback mode (dev only): the heuristic fallback invents
            # people, never belongings.
            return []

        items = [
            {"box": d["box"], "score": d["score"], "label": d["label"]}
            for d in raw
            if d["label"] in BELONGINGS_LABELS
            and (d["box"][2] - d["box"][0]) > 8
            and (d["box"][3] - d["box"][1]) > 8
        ]
        items = dedupe_detections(items)
        for idx, item in enumerate(items):
            item["id"] = idx
        return items

    def _heuristic_fallback(self, image_np: np.ndarray) -> List[Dict[str, Any]]:
        """Fallback detector when neural network weights are offline."""
        h, w = image_np.shape[:2]
        return [
            {
                "id": 0,
                "box": [int(w * 0.35), int(h * 0.2), int(w * 0.65), int(h * 0.85)],
                "score": 0.95,
                "label": "person"
            },
            {
                "id": 1,
                "box": [int(w * 0.75), int(h * 0.3), int(w * 0.88), int(h * 0.65)],
                "score": 0.82,
                "label": "person"
            }
        ]
