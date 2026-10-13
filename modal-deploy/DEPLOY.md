# Deploy the PeopleGone worker to Modal (free tier)

Modal's free plan includes $30/month of compute credits (resets monthly) —
plenty for development and testing. The endpoint sleeps when idle and bills
per second only while processing.

## One-time setup (owner)
1. Sign up at https://modal.com (free; GitHub login works).
2. On the machine that will run the deploy commands:
   ```
   pip install modal
   modal token new
   ```
   This prints a URL — open it, approve. The token is stored in
   `~/.modal.toml` on that machine. Never paste the token into chat or commit it.

## Deploy (from this folder: modal-deploy/ in this repo)
```
modal deploy modal_app.py
```
Self-contained: the worker package is vendored under `server/` in this
folder, and the MAT runtime code is cloned from GitHub at image-build
time (pinned commit, see modal_app.py). No folders outside this repo are
needed.
First build downloads model weights into the image (RT-DETR detector,
SAM 2.1 tiny, MAT checkpoint, LaMa) — expect the build to take a while.
The command prints the web endpoint URL when done.

## Smoke test
```
curl https://<workspace>--peoplegone-worker-web.modal.run/health
curl -X POST https://<workspace>--peoplegone-worker-web.modal.run/process \
  -F file=@some_photo.jpg -F engine=mat -o result.json
```
`result.json` contains `image_base64` (the processed photo) and `meta`
(persons detected, keeper, removed, timings, engine used).
First call after idle = cold start; allow up to ~5 minutes once.

## Notes / limits
- GPU: T4 (16 GB). All current models fit comfortably.
- The endpoint is public-by-URL in this dev setup. Add the API-key step from
  API_CONTRACT.md before sharing the URL widely — anyone with it can spend
  the workspace credits.
- Costs beyond the free $30/month are per-second GPU time; a processed photo
  is on the order of a few tenths of a cent at T4 rates (measure from `meta`
  timings after the first real runs; do not treat this as a quote).
- Rollback/stop: `modal app stop peoplegone-worker`.

## 2026-10-14 — API key gate (Task A)

- Modal secret `peoplegone-worker` created from the worker API key held
  outside the repo; the `web()` function now loads it via
  `secrets=[modal.Secret.from_name("peoplegone-worker")]`.
- `/process` and `/detect` require header `X-Worker-Key` matching the
  secret (constant-time compare). Missing/wrong key → `401`
  `{"ok": false, "error": "unauthorized"}`. If the secret is unset in
  the function, the gate fails closed (401). `/health` stays public.
- `/process` also accepts optional gateway fields (`callback_url`,
  `callback_token`, `job_id`, `result_upload_url`): when present the
  result JPEG is PUT to `result_upload_url` and a JSON notification is
  POSTed to `callback_url`; failures are logged server-side only and
  the normal JSON response is returned regardless.
- Deployed from the repo package and verified live (after ~60 s wait):
  - `GET /health` (no key) → 200 `{"ok": true, "service": "peoplegone-worker"}`
  - `POST /detect` (no key) → 401 `{"ok": false, "error": "unauthorized"}`
  - `POST /detect` (wrong key) → 401 (same body)
  - `POST /process` (no key) → 401 (same body)
  - `POST /process` (with key, mosque photo, engine=mat) → 200,
    ok:true, persons_detected=13, keeper_ids=[0], removed_ids=12
    entries, engine_used=mat, total_seconds=188.95 (CPU worker).

## 2026-10-14 — /touchup endpoint (Task C, worker half; FR-09, §6.4)

- `pipeline.touchup(photo_bytes, mask_png_bytes)` added to both pipeline
  copies (kept byte-identical): threshold mask >127, resize mask
  NEAREST to image size if mismatched (`mask_resized`), inpaint only
  the `get_crop_bounds` crop, composite back with 4px feather onto the
  untouched original; empty mask returns the re-encoded original with
  `touched: false`.
- `POST /touchup` (key-gated): multipart `file` + `mask_png` +
  `engine` (default mat). Verified live on the mosque photo:
  /detect found 13 persons (keeper [0]); a filled-rect mask over
  removed person 1's box [1, 686, 100, 916] (23,100 px) was POSTed
  with the original photo. No-key /touchup → 401.
  Result: output dims == input dims (900×1600), `touched: true`,
  total_seconds 14.46, engine_used mat.
  Pixel diff vs the decoded original (full numbers in
  `touchup_evidence.json`): INSIDE the mask rect mean abs diff 47.0,
  97.4% of pixels differ by >2 (region really changed). OUTSIDE the
  mask rect mean abs diff 0.161, max 23, 1.58% of pixels differ by
  >2 — that is JPEG re-encode noise from the final encode, NOT
  byte-identical outside the mask at the file level (the composite
  itself only writes inside the mask before encoding).
