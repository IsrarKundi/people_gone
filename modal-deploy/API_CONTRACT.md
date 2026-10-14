# PeopleGone Worker — API Contract v2 (dev)

Base URL: whatever Modal prints on deploy (looks like
`https://<workspace>--peoplegone-worker-web.modal.run`).

The contract is engine-agnostic: LaMa / MAT / PowerPaint all sit behind the
same door, and the host (Modal today, RunPod later) can change without the
Flutter app changing.

## GET /health
→ `200 {"ok": true, "service": "peoplegone-worker"}`

## POST /detect  (multipart/form-data)
Stage A analysis endpoint for the Proposal screen (S4). Runs person detection (RT-DETR)
and the keeper heuristic without inpainting, returning bounding boxes and the initial
keep/remove classification.

Fields:
- `file` — the photo (JPEG/PNG), required.

Response `200` JSON:
```json
{
  "ok": true,
  "input_dimensions": [1920, 1080],
  "persons_detected": 3,
  "keeper_ids": [0],
  "removed_ids": [1, 2],
  "persons": [
    {
      "id": 0,
      "box": [120, 80, 450, 900],
      "score": 0.94,
      "is_keeper": true
    },
    {
      "id": 1,
      "box": [800, 200, 920, 600],
      "score": 0.82,
      "is_keeper": false
    }
  ]
}
```

## POST /process  (multipart/form-data)
Fields:
- `file` — the photo (JPEG/PNG), required.
- `engine` — optional, default `"mat"`. One of:
  - `"mat"` — MAT fill (default; best texture fills, never invents objects)
  - `"lama"` — LaMa fill (original pipeline engine)
  - `"auto"` — RacingInpainter: MAT vs PowerPaint raced on large patches
    only (mask ratio >= 0.15 of crop AND >= 40,000 px), ghost-check
    residual picks the winner; `meta.crop_engines` records every crop.
    See RACING_NOTES.md for live verification results.
- `keep` — optional, comma-separated person ids to keep, e.g. `"0,3"`.
  Empty = automatic keeper choice (largest / most central subject).

Response `200` JSON:
```json
{
  "ok": true,
  "image_base64": "<full-resolution result JPEG, base64>",
  "meta": {
    "persons_detected": 13,
    "keeper_ids": [0],
    "removed_ids": [1, 2, 3],
    "persons": [
      {
        "id": 0,
        "box": [120, 80, 450, 900],
        "score": 0.94,
        "is_keeper": true
      }
    ],
    "crops_inpainted": 12,
    "total_seconds": 4.21,
    "engine_requested": "mat",
    "engine_used": "mat",
    "fallbacks_used": []
  }
}
```
The keeper's pixels are never modified — fills are composited only inside the
removal masks, onto the untouched original.

Errors: non-2xx with `{"detail": "..."}` (FastAPI default). A failed fill
stage raises server-side — the worker never returns a silently faked result.

## Client (Flutter) guidance
- First call after idle can be a cold start (model load): allow a long
  timeout (up to 300 s) and retry once before showing an error.
- Send the photo at full resolution; the worker returns full resolution.
- Show `meta.persons_detected / keeper_ids / removed_ids` on the proposal
  screen so the user can correct the keeper via `keep` and re-POST.
- Do NOT hardcode the base URL in the app; read it from remote config / a
  constants file per environment (dev Modal URL today).

## Auth (added 2026-10-14)
`POST /process`, `POST /detect` and `POST /touchup` require header
`X-Worker-Key` matching the `peoplegone-worker` Modal Secret
(constant-time compare; missing/wrong → `401 {"ok": false,
"error": "unauthorized"}`; fails closed if the secret is unset).
`GET /health` stays public. `/process` also accepts optional gateway
fields (`callback_url`, `callback_token`, `job_id`,
`result_upload_url`) for asynchronous result collection by the
Supabase gateway.

## POST /touchup  (multipart/form-data, added 2026-10-14; FR-09)
Brush-fix: re-inpaints only the crop around a user-painted mask.
Fields: `file` (photo, required), `mask_png` (PNG mask, white = fill
region, required), `engine` (optional, default `"mat"`; `"auto"` maps
to MAT here — racing is a /process path only). Response mirrors
/process: `{"ok": true, "image_base64": ..., "meta": {...}}` with
meta carrying `touched`, `mask_area_px`, `mask_resized`,
`total_seconds`, `engine_used`. Output dimensions == input dimensions.


## Gateway (Supabase, added 2026-10-14 — Contract v2)

Base: `{SUPABASE_URL}/functions/v1/`. Every call carries
`Authorization: Bearer <anon JWT>` + `apikey: <anon key>`; error bodies
are `{"error": string}`. The app signs in anonymously (GoTrue REST) and
stores tokens in secure storage. The worker key never reaches the app —
only the gateway holds it (function secret) and calls the worker
server-side.

- `POST create-job {client_job_id, engine?}` → `{job_id, status,
  upload_url|null, persons|null, keeper_ids, removed_ids,
  input_dimensions}`. Idempotent per (install, client_job_id); a fresh
  signed upload URL is minted only while `status='created'`.
- Client PUTs the photo to `upload_url` (the signed URL is the
  credential; no gateway headers).
- `POST analyse-job {job_id}` → runs worker `/detect` server-side,
  stores persons/keeper on the job, status `awaiting_confirm`, returns
  the /detect-shaped payload.
- `POST confirm-job {job_id, keep_ids?, engine?}` → `202`. The gateway
  fires the worker `/process` with a per-job callback token (sha256
  stored on the job row) and a signed result-upload URL; the worker
  PUTs the result JPEG there, then POSTs `worker-callback`.
- `POST worker-callback {job_id, token, meta}` (no JWT; token-hash
  verified) → job `done`, meta stored.
- `GET job-status?job_id=` → `{job_id, status, error, meta|null}`
  (owner-only). `GET get-result?job_id=` → `{download_url, expires_at}`
  when done, else `409 {"error":"not_ready"}`.
- `POST consume-credit {idempotency_key}` → the credit RPC result
  verbatim `{allowed, payment_required, is_pro, saves_left}`. A save is
  charged ONLY here — processing, cancel and failure never charge.
  `payment_required` is a success outcome, not an error.
- `POST refund-credit {idempotency_key}` → `{ok, refunded}`.
- `POST touchup` (multipart) → forwards to worker `/touchup` with the
  key; worker JSON returned verbatim; nothing is stored server-side.
- Retention: private `uploads`/`results` buckets, signed URLs only;
  `sweep_expired()` deletes objects and expires jobs older than 24 h,
  scheduled hourly by pg_cron (job `peoplegone-sweep-hourly`).

Status note (2026-10-14): gateway is deployed and the app client is
built, but `AppConfig.useGateway` still defaults to FALSE — the
scripted live end-to-end run from this dev VM is blocked by the VM
egress proxy (see `supabase/E2E_EVIDENCE.md`); the flag flips only
after that run passes. Until then the app uses the direct worker path
shape with the loud-failure credit gate.

## Not in v2 (planned)
1. Production move: same container contract on RunPod Serverless behind the
   Supabase gateway (built — see above) per PEOPLEGONE_REQUIREMENTS.
