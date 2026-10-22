"""RORem fill engine (production).

Contract (same as every worker inpainter):
    inpaint_crop(image_crop RGB uint8 HxWx3, mask_crop uint8,
                 >0 = hole) -> same-size RGB uint8 array.

RORem is a removal-FINE-TUNED SDXL inpainting model — HF
`LetsThink/RORem`, a StableDiffusionXLInpaintPipeline fine-tune of
diffusers/stable-diffusion-xl-1.0-inpainting-0.1 (its own
model_index.json says so; weights baked into the image at build,
SHA-256 verified there — see modal_app.py). Licence posture is the
owner's eyes-open call (2026-10-23): the publishers label the
weights Apache-2.0; the SDXL-inpainting base is CreativeML Open
RAIL++-M, so the worker treats the model as Open RAIL++-M —
rorem-trial/LICENCE.md holds the full record.

Recipe = the authors' documented one (github.com/leeruibin/RORem
README, "RORem Diffuser" section — the HF model card is empty):
  - AutoPipelineForInpainting, torch_dtype=float16 (their
    variant="fp16" is omitted: the repo ships a single fp16 file
    set with no *.fp16.safetensors variants to select)
  - crop image + mask resized to 512x512 for the call, the fill
    resized back to the crop size afterwards (the authors resize
    the whole input to 512x512; applied per-crop here)
  - the authors' CFG prompt pair, guidance_scale=1.0,
    num_inference_steps=50, strength=0.99
  - NO extra mask dilation: production mask-prep output is already
    dilated / shadow-grown / keeper-carved; the authors' dilate
    option targets raw hand-drawn masks.
  - seeds: base seed 42, per-fill seed = 42 + fill index within
    the job (reset() per job) — deterministic per job.

Weights load LAZILY on the first RORem crop (~7.7 GB VRAM after
load on a T4; measured peak with fills ~9.4 GB). Under
engine="auto" the pipeline wraps this in a MAT fallback (owner's
rule); under engine="rorem" a load/inference failure raises.
"""

from __future__ import annotations

import os
import time

import numpy as np
from PIL import Image

ROREM_DIR = os.environ.get("ROREM_DIR", "/models/rorem")

CFG_PROMPT = (
    "4K, high quality, masterpiece, Highly detailed, Sharp focus, "
    "Professional, photorealistic, realistic"
)
CFG_NEGATIVE = (
    "low quality, worst, bad proportions, blurry, extra finger, "
    "Deformed, disfigured, unclear background"
)

WORK_SIZE = 512
STEPS = 50
GUIDANCE = 1.0
STRENGTH = 0.99


class RORemInpainter:
    """RORem (LetsThink/RORem) inpainter, authors' recipe."""

    fallback_used = False  # this engine never fakes a fill

    def __init__(self, seed: int = 42, steps: int = STEPS,
                 guidance: float = GUIDANCE, strength: float = STRENGTH,
                 prompt: str = CFG_PROMPT, negative: str = CFG_NEGATIVE):
        self.base_seed = seed
        self.steps = steps
        self.guidance = guidance
        self.strength = strength
        self.prompt = prompt
        self.negative = negative
        self.pipe = None
        self._call_idx = 0
        self.last_load_seconds: float = 0.0

    def reset(self) -> None:
        """Per-job reset: fill seeds restart from the base seed."""
        self._call_idx = 0

    def load(self) -> None:
        import torch
        from diffusers import AutoPipelineForInpainting

        t0 = time.time()
        self.pipe = AutoPipelineForInpainting.from_pretrained(
            ROREM_DIR, torch_dtype=torch.float16)
        self.pipe = self.pipe.to("cuda")
        self.pipe.set_progress_bar_config(disable=True)
        self.last_load_seconds = round(time.time() - t0, 2)

    def inpaint_crop(self, image_crop: np.ndarray,
                     mask_crop: np.ndarray) -> np.ndarray:
        import torch

        if self.pipe is None:
            self.load()
        idx = self._call_idx
        self._call_idx += 1

        mask_bool = mask_crop > 127
        if not mask_bool.any():
            return image_crop

        h, w = image_crop.shape[:2]
        img_pil = Image.fromarray(image_crop).resize(
            (WORK_SIZE, WORK_SIZE), Image.LANCZOS)
        mask_pil = Image.fromarray(
            (mask_bool.astype(np.uint8)) * 255).resize(
            (WORK_SIZE, WORK_SIZE), Image.NEAREST)

        generator = torch.Generator("cuda").manual_seed(
            self.base_seed + idx)
        with torch.inference_mode():
            out = self.pipe(
                prompt=self.prompt,
                negative_prompt=self.negative,
                image=img_pil,
                mask_image=mask_pil,
                height=WORK_SIZE,
                width=WORK_SIZE,
                guidance_scale=self.guidance,
                num_inference_steps=self.steps,
                strength=self.strength,
                generator=generator,
            ).images[0]
        result = np.asarray(out.convert("RGB"), dtype=np.uint8)
        if result.shape[:2] != (h, w):
            result = np.asarray(
                Image.fromarray(result).resize((w, h), Image.LANCZOS),
                dtype=np.uint8)
        return result
