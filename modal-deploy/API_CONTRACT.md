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
  - `"auto"` — currently maps to MAT; will race PowerPaint on large patches
    once that stage lands.
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

## Not in v1 (planned, in this order)
1. PowerPaint racing on large patches behind `engine="auto"` + ghost-check pick.
2. Proposal endpoints: `POST /detect` (persons + proposed keeper, no fill)
   so the proposal screen doesn't need a full process call.
3. Auth: a shared API key header (Modal Secret) — REQUIRED before the URL is
   shared beyond the dev team, otherwise anyone with the URL can spend the
   workspace's credits.
4. Production move: same container contract on RunPod Serverless behind the
   Supabase gateway (credit ledger, 24 h photo TTL) per PEOPLEGONE_REQUIREMENTS.
