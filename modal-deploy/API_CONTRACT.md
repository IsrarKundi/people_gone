# PeopleGone Worker — API Contract v3 (dev)

**v3 (2026-10-14, Phase A — belongings, FR-08) is ADDITIVE over v2:**
every v2 field keeps its exact meaning and shape; v3 only ADDS the
`belongings` list and the `/process` confirm fields below. Old clients
ignore the new fields and behave exactly as under v2. The gateway
(Supabase) section at the bottom describes the v2 gateway surface plus
its v3 additions.

**Phase B (2026-10-14, distractions) is additive over the Phase A
shape in the same way:** v3 only ADDS the `distractions` list (below)
and the `/process` meta fields `distractions`,
`distractions_removed`, `distractions_removed_ids`. No field changed
meaning; `contract_version` stays 3.

**Phase B close-out (2026-10-15):** the shipped distraction category
set is EMPTY at launch (`SHIPPED_DISTRACTION_CATEGORIES` in
`server/worker/distractions.py`). Every detection-calibrated category
failed the removal-quality gate (see
`docs/architecture/phase-b-calibration.md`), so `/detect` returns
`distractions: []` and the app group never renders until a category
is enabled there. The contract surface below is unchanged and fully
implemented — this is a config state, not a missing feature.

**Phase D (2026-10-15, reflections — detect + warn only, FR-09) is
additive over the Phase B shape:** `/process` meta only ADDS
`reflection_warning` (bool) and `reflection_regions` (list of
`{person_id, box, surface, kind, score}` — the probable reflection
of a REMOVED person, in original-image pixels). Reflections are
never auto-removed in v1 and never appear in `/detect`; the fields
ride the existing gateway meta round-trip unchanged (worker-callback
stores meta verbatim, job-status returns it when done), so no
gateway change was needed. `contract_version` stays 3. Gate +
evidence: `docs/architecture/phase-d-investigation.md`.

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
  "contract_version": 3,
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
  ],
  "belongings": [
    {
      "id": 0,
      "detected_class": "handbag",
      "box": [700, 300, 790, 420],
      "score": 0.88,
      "tier": "attached",
      "person_id": 1
    },
    {
      "id": 1,
      "detected_class": "suitcase",
      "box": [1500, 700, 1600, 900],
      "score": 0.81,
      "tier": "ambiguous",
      "person_id": null
    }
  ],
  "distractions": [
    {
      "id": 10000,
      "kind": "distraction",
      "category": "car",
      "box": [1600, 500, 1900, 800],
      "score": 0.93
    },
    {
      "id": 10001,
      "kind": "distraction",
      "category": "trash bin",
      "box": [300, 600, 380, 780],
      "score": 0.85
    }
  ]
}
```

**Belongings (v3, Phase A).** The same detector pass also returns the
COCO belongings classes (backpack, handbag, suitcase, umbrella).
Each item is tiered by mask geometry against every person's dilated
halo (see `server/worker/belongings.py`):

- `tier: "attached"` — the item touches exactly ONE person's halo
  above a de-minimis contact bar; `person_id` is that owner. Attached
  belongings follow their person: removed with a removed person,
  protected with a keeper (design X8).
- `tier: "ambiguous"` — ownership is not geometrically certain
  (touches two people, or nobody). `person_id` is null. Ambiguous
  items are the user's decision on S4 (object chips, default Keep,
  design X10) and are removed only when the confirm payload includes
  them in `remove_items`.

`detected_class` is the detector's class label — **a hint, not a
label of record**: the classes are confused with each other in
measurement (handbag vs suitcase vs backpack), so the field is
carried as data the UI may display cautiously, and a future label
fix must not change the field's shape or meaning (it stays
`detected_class`, a plain string). Item `id`s are stable between
/detect and /process on the same photo (same deterministic code
path: dedupe → segment → merge → tier).

Note: /detect now runs SAM segmentation (tiering needs masks), so it
pays the one SAM image encode — expect Stage A to take longer than
the v2 detect-only pass on CPU (~7–10 s more); NFR-02's ≤5 s analysis
target was written for GPU hosting.

**Distractions (v3, Phase B).** Non-person street objects the user
may choose to remove (design X1–X7; default KEEP — nothing is removed
unless the confirm payload includes the id). Two detector sources:
the same RT-DETR pass for the COCO classes car, bus, truck, motorbike
(the checkpoint's own label), bicycle, traffic light, parking meter,
bench, fire hydrant — and OmDet-Turbo Tiny (Apache-2.0, run ONCE per
analysis) for the prompts "trash bin" and "stroller". Every category
carries a per-category score threshold from the Phase B calibration
(`docs/architecture/phase-b-calibration.md`; config lives in
`server/worker/distractions.py` — the ONE place thresholds are set).
Poles and street signs are withheld entirely (spike verdict), and
stop sign is withheld on thin evidence (calibration doc) — they
never appear. Dedupe guarantees one physical object = one item:
persons are never distractions, an attached/ambiguous belonging is
never also a distraction, and an OmDet candidate whose SAM mask is
the same object as a person/belonging/RT-DETR item is suppressed
(RT-DETR wins its own classes). Distraction `id`s live in their own
range (≥ 10000) so they can share the `remove_items` confirm field
with belonging ids without collisions. `category` IS a label of
record (unlike belongings' `detected_class` hint): the calibration
gate passed per category.

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
- `remove_items` — optional (v3), comma-separated AMBIGUOUS belonging
  ids the user chose to remove, e.g. `"1"`. Ids not present in this
  run's analysis are ignored — a stale client can never invent a
  removal. Attached belongings need no entry here: they follow their
  person automatically. **Phase B:** DISTRACTION ids (≥ 10000) ride
  this same field — a distraction is removed only when its id is
  included here; kept distractions are protected (below).
- `detached_items` — optional (v3), comma-separated ATTACHED
  belonging ids the user detached from their person on S4. A detached
  belonging is protected — it is never in any removal mask, even when
  its person is removed (design X9/X11).

`/process` meta additionally carries (v3): `contract_version: 3`,
`belongings` (same shape as /detect), `belongings_removed_ids` (every
belonging actually removed: attached-with-owner + user-included),
`belongings_detached_ids` (detach requests honoured), and
`items_removed` (count of user-included ambiguous items only —
attached belongings are part of their person and are NEVER itemised
in counts, design X16). The ghost check also re-detects belongings
classes in crops that carried items: a surviving item retries with a
re-dilated mask, exactly like a surviving person.

Phase B meta additions: `distractions` (same shape as /detect),
`distractions_removed` (count) and `distractions_removed_ids`.
An included distraction is inpainted on its own native-res crop
through the same engine path (MAT default; large items ride the
racing under `engine="auto"`). **Protected-set clipping (hard
rule):** every distraction mask is clipped to exclude protected
pixels — keeper persons + their belongings + detached belongings +
belongings not included + distractions not included — before
inpainting, and the ghost-retry re-dilation is re-clipped. The
distraction ghost check re-detects the item's own category on its
finished crop with the same detector that found it (residual must
overlap the original box); one retry, mirroring the person pattern.

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
- **Gateway v3 additions (Phase A, 2026-10-14):** `analyse-job`
  returns the worker's `belongings` list and stores it on the job
  (`meta` jsonb — no schema migration); `create-job` returns it with
  the stored proposal on idempotent retries; `confirm-job` accepts
  `remove_item_ids` + `detached_belonging_ids`, records them in job
  meta, and forwards them to the worker as the `remove_items` /
  `detached_items` form fields above. Worker meta (incl.
  `items_removed`) reaches the app verbatim via `job-status`.
- **Gateway Phase B additions (2026-10-14, functions v3):**
  `analyse-job` also returns + stores the worker's `distractions`
  list (same `meta` jsonb, no migration); `create-job` returns it on
  idempotent retries. `confirm-job` needed NO change — distraction
  ids ride the existing `remove_item_ids` field opaquely. Worker
  meta (`distractions_removed`, …) reaches the app via `job-status`
  exactly like the Phase A fields.
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
built. The scripted live end-to-end run from this dev VM is blocked
by the VM egress proxy (see `supabase/E2E_EVIDENCE.md`), and the old
direct worker path is key-gated (401 without the worker key, which
the app never holds) — so `AppConfig.useGateway` now defaults to
TRUE (USE_GATEWAY=false remains as a debug override). The owner's
device run is the end-to-end verification; the S6 interim copy is
retired only after that run passes.

## Not in v2 (planned)
1. Production move: same container contract on RunPod Serverless behind the
   Supabase gateway (built — see above) per PEOPLEGONE_REQUIREMENTS.
