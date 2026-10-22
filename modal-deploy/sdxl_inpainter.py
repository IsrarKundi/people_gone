"""SDXL inpainter — drop-in replacement for PowerPaintInpainter as the
generative leg of RacingInpainter (same inpaint_crop API), Phase E2.

  base model  diffusers/stable-diffusion-xl-1.0-inpainting-0.1 (fp16),
              a true inpainting fine-tune of SDXL base (UNet carries the
              extra masked-image + mask input channels), weights baked
              into the worker image at /models/sdxl-inpaint
  pipeline    StableDiffusionXLInpaintPipeline (pinned diffusers 0.30.3)
  VAE         loaded in fp32 — SDXL's VAE is numerically fragile in
              fp16 and fp32 costs little; the rest of the pipeline is fp16
  scheduler   UniPCMultistepScheduler (same family as PowerPaint)
  removal     strength 1.0 (full regeneration of the masked region),
              guidance 7.5, steps from env XL_STEPS (default 28),
              seed 42 generator on-device, plain generic background
              prompt + the extended plain-language negative list Phase E
              built for PowerPaint (minus its P_obj task token)

Resolution policy (differs from PowerPaint's 640 px rule on purpose —
640 would starve a 1024-trained model): crops are resized to 1024 px
SHORT side, multiples of 8, with a hard total-pixel cap of ~1.6M px
(larger crops are downscaled to the cap); the result is resized back to
the crop size, exactly like the PowerPaint leg.

Weights load LAZILY on the first inpaint_crop call, never at import or
construction. Any load/inference error raises — no fallback inside.
"""
import os
from typing import Optional, Tuple

import numpy as np

MODEL_ID = "diffusers/stable-diffusion-xl-1.0-inpainting-0.1"

# Prompt history (wedding gate photo, SCOPE allows 2–3 variants):
# v1 generic "empty background scenery, no people, no objects" — XL
#   re-dreamed a person into every raced crop (veto fired 4/4).
# v2 named the backdrop but said "decorations" — no people, but XL
#   invented a floral stage arrangement that does not exist.
# v3 names ONLY what is actually behind the subjects: plain drapes.
PROMPT_POSITIVE = (
    "plain draped fabric curtain backdrop, red gold and yellow drapes, "
    "empty stage, no people"
)
# Phase E's extended plain-language negatives (pp_inpainter.py
# NEGATIVE_REMOVAL) minus the PowerPaint-only " P_obj" task token: the
# stock guard alone let SD 1.5 invent people and text into large holes.
NEGATIVE_PROMPT = (
    "person, people, man, woman, face, head, hands, body, crowd, "
    "text, letters, words, sign, logo, watermark"
)

SHORT_SIDE_PX = 1024
MAX_TOTAL_PX = 1_600_000
GUIDANCE_SCALE = 7.5
STRENGTH = 1.0
SEED = 42


def target_size(w: int, h: int, short_side: int = SHORT_SIDE_PX,
                max_total_px: int = MAX_TOTAL_PX) -> Tuple[int, int]:
    """Working size for a (w, h) crop: short side scaled to `short_side`,
    total pixels capped at `max_total_px`, both dims multiples of 8."""
    if w <= 0 or h <= 0:
        raise ValueError(f"invalid crop size {w}x{h}")
    scale = short_side / min(w, h)
    tw, th = w * scale, h * scale
    if tw * th > max_total_px:
        cap_scale = (max_total_px / (tw * th)) ** 0.5
        tw, th = tw * cap_scale, th * cap_scale
    tw = max(64, int(tw) // 8 * 8)
    th = max(64, int(th) // 8 * 8)
    return tw, th


class XLInpainter:
    def __init__(
        self,
        ckpt_dir: Optional[str] = None,
        device: Optional[str] = None,
    ):
        self.ckpt_dir = ckpt_dir or os.environ.get(
            "SDXL_CKPT_DIR", "/models/sdxl-inpaint"
        )
        # None = auto-resolve in _lazy_init (cuda if available, else cpu),
        # the same pattern MatInpainter / PowerPaintInpainter use.
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
        try:
            from diffusers import (
                AutoencoderKL,
                StableDiffusionXLInpaintPipeline,
                UniPCMultistepScheduler,
            )

            # fp32 VAE (see module docstring) passed into the fp16 pipe.
            vae = AutoencoderKL.from_pretrained(
                self.ckpt_dir,
                subfolder="vae",
                torch_dtype=torch.float32,
                # Only fp16 weight files are baked into the image; without
                # the variant the loader looks for the plain filename.
                variant="fp16",
                local_files_only=True,
            )
            # This repo's VAE config ships force_upcast=False, but the
            # fp16 pipeline feeds fp16 tensors into the fp32 VAE and the
            # encode dies on the dtype mismatch. force_upcast is the
            # pipeline's own switch for exactly this pairing: it makes
            # _encode_vae_image upcast its input to fp32 (third smoke).
            vae.config.force_upcast = True
            pipe = StableDiffusionXLInpaintPipeline.from_pretrained(
                self.ckpt_dir,
                torch_dtype=torch.float16,
                variant="fp16",
                safety_checker=None,
                local_files_only=True,
                vae=vae,
            )
            pipe.scheduler = UniPCMultistepScheduler.from_config(pipe.scheduler.config)
            pipe.to(self.device)
            pipe.enable_attention_slicing()
            pipe.set_progress_bar_config(disable=True)
        except Exception as e:
            raise RuntimeError(
                f"Stage 'inpainter' failed to load SDXL model: {e}. "
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
        tw, th = target_size(w, h)
        img_pil = Image.fromarray(image_crop).resize((tw, th), Image.LANCZOS)
        msk_pil = Image.fromarray(mask_crop).resize((tw, th), Image.NEAREST)
        gen = torch.Generator(device=self.device).manual_seed(SEED)
        out = self._pipe(
            prompt=PROMPT_POSITIVE,
            negative_prompt=NEGATIVE_PROMPT,
            image=img_pil,
            mask_image=msk_pil,
            height=th,
            width=tw,
            num_inference_steps=int(os.environ.get("XL_STEPS", "28")),
            guidance_scale=GUIDANCE_SCALE,
            strength=STRENGTH,
            generator=gen,
        ).images[0]
        if out.size != (w, h):
            out = out.resize((w, h), Image.LANCZOS)
        return np.array(out)
