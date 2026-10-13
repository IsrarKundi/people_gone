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
    # Worker code (source of truth: phase0-run/server on the build machine)
    .add_local_dir("../phase0-run/server", remote_path="/app/server")
    .add_local_dir(
        "../phase0-run/MAT-repo",
        remote_path="/app/MAT-repo",
        ignore=["test_sets", "figures", "training", "metrics", "losses",
                "evaluatoin", "datasets", "__pycache__"],
    )
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


@app.function(image=modal.Image.debian_slim().pip_install("fastapi[standard]"))
@modal.asgi_app()
def web():
    import base64

    from fastapi import FastAPI, File, Form, UploadFile
    from fastapi.responses import JSONResponse

    api = FastAPI(title="PeopleGone worker (dev)")

    @api.get("/health")
    def health():
        return {"ok": True, "service": "peoplegone-worker"}

    @api.post("/process")
    async def process(
        file: UploadFile = File(...),
        engine: str = Form("mat"),
        keep: str = Form(""),  # comma-separated person ids to KEEP, e.g. "0,3"
    ):
        data = await file.read()
        keep_ids = [int(x) for x in keep.split(",") if x.strip() != ""] or None
        jpeg, meta = Processor().process.remote(data, engine=engine, keep_ids=keep_ids)
        return JSONResponse(
            {
                "ok": True,
                "image_base64": base64.b64encode(jpeg).decode(),
                "meta": meta,
            }
        )

    return api
