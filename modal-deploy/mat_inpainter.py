"""MAT inpainter — drop-in replacement for LamaInpainter (same inpaint_crop API).

Verified behaviour (CPU patch tests, 2026-10-12/13): MAT (Places_512 full-data
checkpoint) beat LaMa on texture fills (grass), tied on stone plaza, and never
hallucinates objects. Two traps, both handled here:
  1. MAT's mask polarity is INVERTED vs the worker convention
     (MAT multiplies the image by the mask: 1 = KEEP, 0 = hole).
  2. Its checkpoint was saved from CUDA tensors; loading pins map_location to
     the current device.
Fails loudly on any error — never substitutes a fake fill.
"""
import os
import sys
from typing import Optional

import numpy as np


class MatInpainter:
    def __init__(self, checkpoint_path: Optional[str] = None, device: Optional[str] = None):
        self.checkpoint_path = checkpoint_path or os.environ.get(
            "MAT_CKPT", "/models/mat/Places_512_FullData.pkl"
        )
        self.device = device
        self._model = None
        self._initialized = False
        self.fallback_used: bool = False

    def _lazy_init(self):
        if self._initialized:
            return
        import torch

        if self.device is None:
            self.device = "cuda" if torch.cuda.is_available() else "cpu"

        mat_repo = os.environ.get("MAT_REPO", "/app/MAT-repo")
        if mat_repo not in sys.path:
            sys.path.insert(0, mat_repo)
        import dnnlib
        import legacy
        from networks.mat import Generator

        # Force checkpoint storages onto our device (checkpoint came from CUDA).
        import torch.serialization as _ts

        _orig = _ts.default_restore_location
        _ts.default_restore_location = lambda storage, loc: _orig(storage, self.device)
        try:
            with dnnlib.util.open_url(self.checkpoint_path) as f:
                g_saved = legacy.load_network_pkl(f)["G_ema"]
        finally:
            _ts.default_restore_location = _orig
        g_saved = g_saved.to(self.device).eval().requires_grad_(False)

        G = (
            Generator(z_dim=512, c_dim=0, w_dim=512, img_resolution=512, img_channels=3)
            .to(self.device)
            .eval()
            .requires_grad_(False)
        )

        def named_pb(m):
            return list(m.named_parameters()) + list(m.named_buffers())

        src = {n: t for n, t in named_pb(g_saved)}
        for n, t in named_pb(G):
            if n in src:
                t.copy_(src[n].detach()).requires_grad_(t.requires_grad)
        self._model = G
        self._initialized = True  # only after a fully successful load

    def inpaint_crop(self, image_crop: np.ndarray, mask_crop: np.ndarray) -> np.ndarray:
        """image_crop: RGB uint8 (H, W, 3). mask_crop: uint8 (H, W), >0 = inpaint."""
        self.fallback_used = False
        self._lazy_init()
        import torch
        from PIL import Image

        h, w = image_crop.shape[:2]
        img512 = np.array(Image.fromarray(image_crop).resize((512, 512), Image.LANCZOS))
        # Invert polarity: our 255 = hole; MAT wants 1.0 = keep.
        msk512 = 1.0 - (
            np.array(Image.fromarray(mask_crop).resize((512, 512), Image.NEAREST)).astype(np.float32)
            / 255.0
        )
        image = (torch.from_numpy(img512.transpose(2, 0, 1)).float() / 127.5 - 1).unsqueeze(0)
        mask = torch.from_numpy(msk512).float().unsqueeze(0).unsqueeze(0)
        z = torch.from_numpy(np.random.RandomState(240).randn(1, self._model.z_dim).astype(np.float32))
        label = torch.zeros([1, self._model.c_dim])
        with torch.no_grad():
            out = self._model(
                image.to(self.device),
                mask.to(self.device),
                z.to(self.device),
                label.to(self.device),
                truncation_psi=1,
                noise_mode="const",
            )
        out = (out.permute(0, 2, 3, 1) * 127.5 + 127.5).round().clamp(0, 255).to(torch.uint8)
        out = out[0].cpu().numpy()
        if out.shape[:2] != (h, w):
            out = np.array(Image.fromarray(out).resize((w, h), Image.LANCZOS))
        return out
