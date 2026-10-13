"""PeopleGone worker on Modal (serverless GPU, free-tier friendly).

Engine policy (from the 2026-10-12/13 patch tests):
  default fill = MAT   (best texture fills, never invents objects, fast)
  fallback     = LaMa  (selectable via engine="lama"; original pipeline engine)
  PowerPaint racing on large patches = next iteration (engine="auto" maps to
  MAT until then).

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
        "transformers==4.44.2",
        "huggingface_hub",
        "hydra-core",
        "iopath",
        "timm",
        "click",
        "requests",
        "fastapi[standard]",
    )
    .pip_install("simple-lama-inpainting==0.1.2", extra_options="--no-deps")
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
        }
    )
    # Bake model weights into the image so cold starts don't download GBs.
    .run_commands(
        "python -c \""
        "from huggingface_hub import snapshot_download, hf_hub_download; "
        "snapshot_download('PekingU/rtdetr_r50vd'); "
        "snapshot_download('facebook/sam2.1-hiera-tiny'); "
        "hf_hub_download('Icar/mat_places512_full', 'Places_512_FullData.pkl', "
        "local_dir='/models/mat')\"",
        # LaMa weights (simple-lama fetches its TorchScript file on first use)
        "python -c \"from simple_lama_inpainting import SimpleLama; SimpleLama()\" || true",
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
)

app = modal.App(APP_NAME, image=image)


# NOTE: GPU ("T4") requires a payment method on the Modal account (the free
# $30/mo credits still apply after it's added). Until then we deploy CPU-only
# (4 cores / 8 GB) — slower (~1-3 min/photo) but it proves the full
# endpoint + pipeline + app contract end to end. To upgrade: add the card in
# Modal billing, change this decorator to gpu="T4" (drop cpu/memory), redeploy.
@app.cls(cpu=4.0, memory=8192, timeout=900, scaledown_window=180)
class Processor:
    @modal.enter()
    def load(self):
        import sys

        sys.path.insert(0, "/app/server")
        sys.path.insert(0, "/app")
        from worker.pipeline import PeopleGonePipeline
        from mat_inpainter import MatInpainter

        self.pipeline = PeopleGonePipeline()
        self._lama = self.pipeline.inpainter  # pipeline's own LaMa inpainter
        self._mat = MatInpainter()

    @modal.method()
    def process(self, image_bytes: bytes, engine: str = "mat", keep_ids: list = None):
        # Engine swap: the pipeline only calls inpainter.inpaint_crop(...)
        if engine == "lama":
            self.pipeline.inpainter = self._lama
        else:  # "mat" (default) and "auto" (PP racing lands here later)
            self.pipeline.inpainter = self._mat
        jpeg, meta = self.pipeline.process(image_bytes, keep=keep_ids)
        meta = dict(meta)
        meta["engine_requested"] = engine
        meta["engine_used"] = "lama" if engine == "lama" else "mat"
        return jpeg, meta

    @modal.method()
    def detect(self, image_bytes: bytes):
        return self.pipeline.detect(image_bytes)

    @modal.method()
    def touchup(self, image_bytes: bytes, mask_bytes: bytes, engine: str = "mat"):
        # Same engine-swap pattern as process().
        if engine == "lama":
            self.pipeline.inpainter = self._lama
        else:  # "mat" (default) and "auto" (PP racing lands here later)
            self.pipeline.inpainter = self._mat
        jpeg, meta = self.pipeline.touchup(image_bytes, mask_bytes)
        meta = dict(meta)
        meta["engine_requested"] = engine
        meta["engine_used"] = "lama" if engine == "lama" else "mat"
        return jpeg, meta


@app.function(
    image=modal.Image.debian_slim().pip_install("fastapi[standard]", "requests"),
    secrets=[modal.Secret.from_name("peoplegone-worker")],
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
        jpeg, meta = Processor().process.remote(data, engine=engine, keep_ids=keep_ids)
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
