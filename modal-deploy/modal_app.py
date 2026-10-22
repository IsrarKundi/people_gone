"""PeopleGone worker on Modal (serverless GPU, free-tier friendly).

Engine policy:
  default fill = MAT   (best texture fills, never invents objects, fast)
  fallback     = LaMa  (selectable via engine="lama"; original pipeline engine)
  engine="rorem"       = RORem fills every crop (explicit force; the
                         removal-fine-tuned SDXL inpainter integrated
                         2026-10-23 — see rorem_inpainter.py).
  engine="auto"        = the OWNER'S ROUTING RULE (2026-10-23,
                         server/worker/routing.py): removals < 6 ->
                         RORem; a removal touching a keeper's guard
                         zone AND removals < 11 -> RORem; else MAT.
                         (Thresholds widened by the owner later on
                         2026-10-23 — originally < 3 / < 8.)
                         One engine per photo; a RORem failure under
                         "auto" completes the job with MAT and the
                         meta says so (routing_reason=
                         "rorem_failed_fallback"). Meta always
                         carries engine_used / routing_reason /
                         removal_count / overlap_detected.
  (The 2026-10-22 PowerPaint racing meaning of "auto" was reverted
  the same day — ff64281 — and is NOT what "auto" means now.
  pp_inpainter.py / racing_inpainter.py remain in the image,
  unwired.)

Run (from this folder, after `modal token new`):
    modal deploy modal_app.py
Smoke test:
    curl -X POST <endpoint>/process -F file=@photo.jpg -F engine=mat
"""
import modal

APP_NAME = "peoplegone-worker"

# ---------------------------------------------------------------- image build
image = (
    modal.Image.debian_slim(python_version="3.12")
    .apt_install("git", "libgl1", "libglib2.0-0", "build-essential", "ninja-build")
    .pip_install(
        "torch==2.4.0",
        "torchvision==0.19.0",
        "numpy<2",
        "pillow==10.4.0",
        "opencv-python-headless",
        # 4.46.3 (Phase B): OmDet-Turbo needs transformers >= 4.45; the
        # bump was spike-verified (docs/architecture/phase-b-spike.md) and
        # is regression-gated on the mosque /detect evidence.
        "transformers==4.46.3",
        "huggingface_hub",
        "hydra-core",
        "iopath",
        "timm",
        "click",
        "requests",
        "fastapi[standard]",
    )
    .pip_install("simple-lama-inpainting==0.1.2", extra_options="--no-deps")
    # PowerPaint racing stack (Step 3): versions match the Phase 0 harness
    # env exactly (diffusers 0.30.3, mmengine 0.10.7, accelerate 0.34.2).
    .pip_install(
        "diffusers==0.30.3",
        "mmengine==0.10.7",
        "accelerate==0.34.2",
        "safetensors",
    )
    # sam2 the way that actually installs on this stack (no source builds)
    .run_commands(
        "pip install --no-deps --no-build-isolation "
        "git+https://github.com/facebookresearch/sam2.git"
    )
    .env(
        {
            "HF_HOME": "/models/hf",
            "TORCH_HOME": "/models/torch",
            "MAT_CKPT": "/models/mat/Places_512_FullData.pkl",
            "MAT_REPO": "/app/MAT-repo",
            "PG_ALLOW_FALLBACKS": "0",
            "PP_REPO": "/app/PowerPaint-repo",
            "PP_CKPT_DIR": "/models/powerpaint",
            "PP_STEPS": "30",
            "ROREM_DIR": "/models/rorem",
        }
    )
    # Bake model weights into the image so cold starts don't download GBs.
    .run_commands(
        "python -c \""
        "from huggingface_hub import snapshot_download, hf_hub_download; "
        "snapshot_download('PekingU/rtdetr_r50vd'); "
        "snapshot_download('facebook/sam2.1-hiera-tiny'); "
        "snapshot_download('omlab/omdet-turbo-swin-tiny-hf'); "
        "hf_hub_download('Icar/mat_places512_full', 'Places_512_FullData.pkl', "
        "local_dir='/models/mat')\"",
        # LaMa weights (simple-lama fetches its TorchScript file on first use)
        "python -c \"from simple_lama_inpainting import SimpleLama; SimpleLama()\" || true",
        # PowerPaint base model + trained task weights (racing, Step 3)
        "python -c \""
        "from huggingface_hub import snapshot_download, hf_hub_download; "
        "snapshot_download('runwayml/stable-diffusion-inpainting'); "
        "hf_hub_download('JunhaoZhuang/PowerPaint-v1', 'unet/unet.safetensors', "
        "local_dir='/models/powerpaint'); "
        "hf_hub_download('JunhaoZhuang/PowerPaint-v1', "
        "'text_encoder/text_encoder.safetensors', local_dir='/models/powerpaint')\"",
        # RORem weights (2026-10-23 integration): full SDXL-inpaint
        # pipeline, baked like every other model.
        "python -c \""
        "from huggingface_hub import snapshot_download; "
        "snapshot_download('LetsThink/RORem', local_dir='/models/rorem')\"",
        # Verify the RORem UNet against the SHA-256 published in the
        # HF API listing (read 2026-10-23) — build aborts on mismatch.
        "python -c \""
        "import hashlib; "
        "h = hashlib.sha256(); "
        "f = open('/models/rorem/unet/diffusion_pytorch_model.safetensors', 'rb'); "
        "[h.update(c) for c in iter(lambda: f.read(1 << 22), b'')]; "
        "d = h.hexdigest(); print('rorem unet sha256:', d); "
        "assert d == 'ed10552914ce17189e9544071b2b3d1cbd467834e0e5a7b79469dc32800b8b4e', d\"",
    )
    # PowerPaint runtime code, pinned to the exact commit the Phase 0
    # harness ran with (open-mmlab/PowerPaint @ 5b4c3d5, 2024-08-29).
    .run_commands(
        "git clone https://github.com/open-mmlab/PowerPaint.git /app/PowerPaint-repo"
        " && cd /app/PowerPaint-repo"
        " && git checkout 5b4c3d52291709fcec2a1870d987da693fd3549c"
    )
    # MAT runtime code, cloned at image-build time (same pattern as sam2
    # above) instead of copied from a build-machine folder, so this deploy
    # works from a clean clone of this repo. Pinned to the exact commit the
    # 2026-10-13 smoke test ran with (fenglinglwb/MAT @ d273d89, 2022-10-13).
    # Only dnnlib / legacy / networks / torch_utils are imported at runtime
    # (see mat_inpainter.py); the training/dataset folders are deleted.
    .run_commands(
        "git clone https://github.com/fenglinglwb/MAT.git /app/MAT-repo"
        " && cd /app/MAT-repo"
        " && git checkout d273d891ecdad2e1df106516423a75bc45b2d800"
        " && rm -rf test_sets figures training metrics losses evaluatoin"
        " datasets __pycache__"
    )
    # Worker code — vendored in this repo under modal-deploy/server/
    # (copied from the Phase 0 harness; see server/README.md)
    .add_local_dir("server", remote_path="/app/server")
    .add_local_file("mat_inpainter.py", remote_path="/app/mat_inpainter.py")
    .add_local_file("pp_inpainter.py", remote_path="/app/pp_inpainter.py")
    .add_local_file("racing_inpainter.py", remote_path="/app/racing_inpainter.py")
    .add_local_file("rorem_inpainter.py", remote_path="/app/rorem_inpainter.py")
)

app = modal.App(APP_NAME, image=image)


# GPU (owner's order, 2026-10-23): the whole worker runs on a T4 —
# MAT included ("put mat on gpu too"). RORem cannot run usefully on
# CPU (~6 s/fill on T4 vs minutes on CPU), and Phase E (2026-10-22)
# proved this exact GPU configuration for MAT before its model work
# was reverted. A payment method is on the account (added
# 2026-10-15); the free $30/mo credits still apply first.
# scaledown_window=180 (unchanged from the CPU era): a burst of the
# owner's testing reuses one warm container, and the idle tail is
# ~3 min of T4 time (~$0.03) per cold start.
# timeout=1800 (raised from 900 on 2026-10-14): a 29 MP photo takes
# longer than 900 s end-to-end, and the web function below timed out
# at Modal's 300 s default while waiting.
@app.cls(gpu="T4", timeout=1800, scaledown_window=180)
class Processor:
    @modal.enter()
    def load(self):
        import sys

        sys.path.insert(0, "/app/server")
        sys.path.insert(0, "/app")
        from worker.pipeline import PeopleGonePipeline
        from mat_inpainter import MatInpainter
        from rorem_inpainter import RORemInpainter

        self.pipeline = PeopleGonePipeline()
        self._lama = self.pipeline.inpainter  # pipeline's own LaMa inpainter
        self._mat = MatInpainter()
        # RORem: constructed here, weights load LAZILY on its first
        # crop — a MAT-only job never pays the RORem load or VRAM.
        self._rorem = RORemInpainter()
        # Engine routing registry (worker/routing.py): the pipeline
        # picks per job from engine_request — forced engines and the
        # owner's "auto" rule both resolve through this dict.
        self.pipeline.inpainters = {
            "mat": self._mat,
            "lama": self._lama,
            "rorem": self._rorem,
        }

    @modal.method()
    def process(self, image_bytes: bytes, engine: str = "mat", keep_ids: list = None,
                remove_item_ids: list = None, detached_belonging_ids: list = None):
        # The pipeline resolves the engine per job (routing rule for
        # "auto", forced otherwise) and stamps the meta itself:
        # engine_used / routing_reason / removal_count /
        # overlap_detected all come back in meta.
        if engine not in ("mat", "lama", "rorem", "auto"):
            engine = "mat"
        self.pipeline.engine_request = engine
        if engine in ("auto", "rorem"):
            self._rorem.reset()  # per-job deterministic fill seeds
        jpeg, meta = self.pipeline.process(
            image_bytes, keep=keep_ids,
            remove_item_ids=remove_item_ids,
            detached_belonging_ids=detached_belonging_ids,
        )
        meta = dict(meta)
        meta["engine_requested"] = engine
        if not meta.get("engine_used"):
            meta["engine_used"] = engine if engine != "auto" else "mat"
        return jpeg, meta

    @modal.method()
    def detect(self, image_bytes: bytes):
        return self.pipeline.detect(image_bytes)

    @modal.method()
    def touchup(self, image_bytes: bytes, mask_bytes: bytes, engine: str = "mat"):
        # Same engine-swap pattern as process(), except "auto" maps to
        # MAT here: PowerPaint racing is a /process path only.
        if engine == "lama":
            self.pipeline.inpainter = self._lama
        else:  # "mat" (default) and "auto"
            self.pipeline.inpainter = self._mat
        jpeg, meta = self.pipeline.touchup(image_bytes, mask_bytes)
        meta = dict(meta)
        meta["engine_requested"] = engine
        meta["engine_used"] = "lama" if engine == "lama" else "mat"
        return jpeg, meta


@app.function(
    image=modal.Image.debian_slim().pip_install("fastapi[standard]", "requests"),
    secrets=[modal.Secret.from_name("peoplegone-worker")],
    # Must outlast a Processor call: Modal's 300 s default killed large
    # /process requests at ~305 s on 2026-10-14 (see RACING_NOTES.md).
    timeout=1800,
)
@modal.asgi_app()
def web():
    import base64
    import hmac
    import os

    import requests
    from fastapi import FastAPI, File, Form, Header, UploadFile
    from fastapi.responses import JSONResponse

    api = FastAPI(title="PeopleGone worker (dev)")

    def _authorized(x_worker_key):
        # Fail CLOSED: if the secret is not configured in this function,
        # nothing is authorized — never fall back to open access.
        expected = os.environ.get("WORKER_API_KEY")
        if not expected or not x_worker_key:
            return False
        return hmac.compare_digest(x_worker_key, expected)

    def _unauthorized():
        return JSONResponse(
            status_code=401, content={"ok": False, "error": "unauthorized"}
        )

    @api.get("/health")
    def health():
        return {"ok": True, "service": "peoplegone-worker"}

    @api.post("/detect")
    async def detect(
        file: UploadFile = File(...),
        x_worker_key: str = Header(default=None, alias="X-Worker-Key"),
    ):
        if not _authorized(x_worker_key):
            return _unauthorized()
        data = await file.read()
        res = Processor().detect.remote(data)
        return JSONResponse(res)

    @api.post("/process")
    async def process(
        file: UploadFile = File(...),
        engine: str = Form("mat"),
        keep: str = Form(""),  # comma-separated person ids to KEEP, e.g. "0,3"
        remove_items: str = Form(""),  # CSV ambiguous-belonging ids to REMOVE (v3)
        detached_items: str = Form(""),  # CSV attached-belonging ids to DETACH/protect (v3)
        callback_url: str = Form(""),
        callback_token: str = Form(""),
        job_id: str = Form(""),
        result_upload_url: str = Form(""),
        x_worker_key: str = Header(default=None, alias="X-Worker-Key"),
    ):
        if not _authorized(x_worker_key):
            return _unauthorized()
        data = await file.read()
        keep_ids = [int(x) for x in keep.split(",") if x.strip() != ""] or None
        remove_item_ids = [int(x) for x in remove_items.split(",") if x.strip() != ""] or None
        detached_ids = [int(x) for x in detached_items.split(",") if x.strip() != ""] or None
        jpeg, meta = Processor().process.remote(
            data, engine=engine, keep_ids=keep_ids,
            remove_item_ids=remove_item_ids,
            detached_belonging_ids=detached_ids,
        )
        # Optional async collection by the Supabase gateway: upload the
        # result JPEG to a pre-signed URL, then notify the callback.
        # Failures here are logged server-side only — the direct response
        # below is returned regardless, exactly as before.
        if result_upload_url:
            try:
                requests.put(
                    result_upload_url,
                    data=jpeg,
                    headers={"Content-Type": "image/jpeg"},
                    timeout=120,
                )
            except Exception as exc:  # noqa: BLE001 - log only, never fail the call
                print(f"result_upload_url PUT failed for job {job_id}: {exc}")
        if callback_url:
            try:
                requests.post(
                    callback_url,
                    json={"job_id": job_id, "token": callback_token, "meta": meta},
                    timeout=30,
                )
            except Exception as exc:  # noqa: BLE001 - log only, never fail the call
                print(f"callback_url POST failed for job {job_id}: {exc}")
        return JSONResponse(
            {
                "ok": True,
                "image_base64": base64.b64encode(jpeg).decode(),
                "meta": meta,
            }
        )

    @api.post("/touchup")
    async def touchup(
        file: UploadFile = File(...),
        mask_png: UploadFile = File(...),
        engine: str = Form("mat"),
        x_worker_key: str = Header(default=None, alias="X-Worker-Key"),
    ):
        if not _authorized(x_worker_key):
            return _unauthorized()
        data = await file.read()
        mask_data = await mask_png.read()
        jpeg, meta = Processor().touchup.remote(data, mask_data, engine=engine)
        return JSONResponse(
            {
                "ok": True,
                "image_base64": base64.b64encode(jpeg).decode(),
                "meta": meta,
            }
        )

    return api
