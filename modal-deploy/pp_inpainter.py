"""PowerPaint v1 inpainter — drop-in replacement for LamaInpainter
(same inpaint_crop API), recipe taken verbatim from the Phase 0 harness
(phase0-run/pp_apply.py):

  base model  runwayml/stable-diffusion-inpainting (fp32; device
              auto-resolves CUDA-when-available since Phase E, mirroring
              MatInpainter — CPU-only was the Phase A racing blocker)
  tokenizer   TokenizerWrapper + add_tokens for P_ctxt/P_shape/P_obj,
              num_vectors_per_token parsed from the official repo's app.py
  weights     JunhaoZhuang/PowerPaint-v1 unet + text_encoder safetensors,
              loaded with the non-strict + verify pattern (the checkpoint
              carries position_ids, which transformers 4.44 keeps out of
              the state dict — every other tensor must land)
  scheduler   UniPCMultistepScheduler
  removal     promptA = promptB = "empty scene blur  P_ctxt",
              negatives " P_obj", guidance 10, seed 42,
              crops resized to 640px short side (multiples of 8),
              steps from env PP_STEPS (default 30)

Weights load LAZILY on the first inpaint_crop call, never at import or
construction. Any load/inference error raises — no fallback inside.
"""
import os
import re
import sys
from typing import Optional

import numpy as np

PROMPT_REMOVAL = "empty scene blur  P_ctxt"
# Negative extended in Phase E: the stock " P_obj" alone let the model
# invent a phantom person and a fake text sign into large wedding-photo
# holes (2026-10-22) — plain-language negatives are the standard guard.
NEGATIVE_REMOVAL = (
    "person, people, man, woman, face, head, hands, body, crowd, "
    "text, letters, words, sign, logo, watermark  P_obj"
)


class PowerPaintInpainter:
    def __init__(
        self,
        repo_dir: Optional[str] = None,
        ckpt_dir: Optional[str] = None,
        device: Optional[str] = None,
    ):
        self.repo_dir = repo_dir or os.environ.get("PP_REPO", "/app/PowerPaint-repo")
        self.ckpt_dir = ckpt_dir or os.environ.get("PP_CKPT_DIR", "/models/powerpaint")
        # None = auto-resolve in _lazy_init (cuda if available, else cpu),
        # the same pattern MatInpainter uses. An explicit value wins.
        self.device = device
        self._pipe = None
        self._initialized = False
        self.fallback_used: bool = False

    def _lazy_init(self):
        if self._initialized:
            return
        import torch

        if self.device is None:
            self.device = "cuda" if torch.cuda.is_available() else "cpu"

        torch.set_num_threads(4)
        if self.repo_dir not in sys.path:
            sys.path.insert(0, self.repo_dir)

        try:
            from safetensors.torch import load_file as _load_file
            from safetensors.torch import load_model
            from diffusers import UniPCMultistepScheduler
            from powerpaint.pipelines.pipeline_PowerPaint import (
                StableDiffusionInpaintPipeline as PPPipeline,
            )
            from powerpaint.utils.utils import TokenizerWrapper, add_tokens

            pipe = PPPipeline.from_pretrained(
                "runwayml/stable-diffusion-inpainting",
                torch_dtype=torch.float32,
                safety_checker=None,
                local_files_only=True,
            )
            pipe.tokenizer = TokenizerWrapper(
                from_pretrained="runwayml/stable-diffusion-inpainting",
                subfolder="tokenizer",
                revision=None,
                local_files_only=True,
            )
            # encoding pinned: the Modal image's default locale is ASCII
            # and PowerPaint's app.py carries UTF-8 bytes — a bare open()
            # dies here (first PP load inside the container, Phase E).
            app_src = open(os.path.join(self.repo_dir, "app.py"), encoding="utf-8").read()
            nvec = int(re.search(r"num_vectors_per_token=(\d+)", app_src).group(1))
            add_tokens(
                tokenizer=pipe.tokenizer,
                text_encoder=pipe.text_encoder,
                placeholder_tokens=["P_ctxt", "P_shape", "P_obj"],
                initialize_tokens=["a", "a", "a"],
                num_vectors_per_token=nvec,
            )
            load_model(
                pipe.unet,
                os.path.join(self.ckpt_dir, "unet", "unet.safetensors"),
            )
            # Non-strict load + verify (see module docstring).
            _te_sd = _load_file(
                os.path.join(self.ckpt_dir, "text_encoder", "text_encoder.safetensors")
            )
            _missing, _unexpected = pipe.text_encoder.load_state_dict(
                _te_sd, strict=False
            )
            _missing = [k for k in _missing if "position_ids" not in k]
            _unexpected = [k for k in _unexpected if "position_ids" not in k]
            if _missing or _unexpected:
                raise RuntimeError(
                    "PowerPaint text encoder weights did not fully land: "
                    f"missing={_missing} unexpected={_unexpected}"
                )
            pipe.scheduler = UniPCMultistepScheduler.from_config(pipe.scheduler.config)
            pipe.to(self.device)
            pipe.enable_attention_slicing()
            pipe.set_progress_bar_config(disable=True)
        except Exception as e:
            raise RuntimeError(
                f"Stage 'inpainter' failed to load PowerPaint model: {e}. "
                "Silent fallbacks are disabled."
            ) from e
        self._pipe = pipe
        self._initialized = True  # only after a fully successful load

    def inpaint_crop(self, image_crop: np.ndarray, mask_crop: np.ndarray) -> np.ndarray:
        """image_crop: RGB uint8 (H, W, 3). mask_crop: uint8 (H, W), >0 = inpaint."""
        self.fallback_used = False
        self._lazy_init()
        import torch
        from PIL import Image

        h, w = image_crop.shape[:2]
        scale = 640.0 / min(h, w)
        tw = max(64, int(w * scale) // 8 * 8)
        th = max(64, int(h * scale) // 8 * 8)
        img_pil = Image.fromarray(image_crop).resize((tw, th), Image.LANCZOS)
        msk_pil = Image.fromarray(mask_crop).resize((tw, th), Image.NEAREST)
        gen = torch.Generator(device=self.device).manual_seed(42)
        out = self._pipe(
            promptA=PROMPT_REMOVAL,
            promptB=PROMPT_REMOVAL,
            negative_promptA=NEGATIVE_REMOVAL,
            negative_promptB=NEGATIVE_REMOVAL,
            image=img_pil,
            mask=msk_pil,
            num_inference_steps=int(os.environ.get("PP_STEPS", "30")),
            guidance_scale=10.0,
            generator=gen,
        ).images[0]
        if out.size != (w, h):
            out = out.resize((w, h), Image.LANCZOS)
        return np.array(out)
