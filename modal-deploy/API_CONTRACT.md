# PeopleGone Worker — API Contract v1 (dev)

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

## Not in v1 (planned)
1. Production move: same container contract on RunPod Serverless behind the
   Supabase gateway (credit ledger, 24 h photo TTL) per PEOPLEGONE_REQUIREMENTS.
