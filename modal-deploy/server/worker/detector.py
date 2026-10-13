"""
Person Detector Module — PeopleGone Phase 0
Uses permissive Apache-2.0 checkpoints (RT-DETR or DETR) via Hugging Face.
Ultralytics YOLO is strictly forbidden.
"""

import os
from typing import List, Dict, Any, Optional
import numpy as np

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

    def detect_persons(self, image_np: np.ndarray) -> List[Dict[str, Any]]:
        """
        Detects all persons in an RGB image.
        Returns a list of dicts:
        [{'id': int, 'box': [x1, y1, x2, y2], 'score': float, 'label': 'person'}]
        """
        self.fallback_used = False
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

                persons = []
                person_idx = 0
                for score, label_id, box in zip(results["scores"], results["labels"], results["boxes"]):
                    label_name = self._model.config.id2label.get(label_id.item(), "").lower()
                    if "person" in label_name:
                        b = box.tolist()
                        x1 = max(0, int(round(b[0])))
                        y1 = max(0, int(round(b[1])))
                        x2 = min(w, int(round(b[2])))
                        y2 = min(h, int(round(b[3])))
                        if (x2 - x1) > 10 and (y2 - y1) > 20:
                            persons.append({
                                "id": person_idx,
                                "box": [x1, y1, x2, y2],
                                "score": float(score.item()),
                                "label": "person"
                            })
                            person_idx += 1
                return persons
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
        return self._heuristic_fallback(image_np)

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
