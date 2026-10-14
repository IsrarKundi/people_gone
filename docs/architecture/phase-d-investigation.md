# Phase D investigation — reflections v1 (detect + warn + guided brush)

**Status:** INVESTIGATION IN PROGRESS — approach, licence position,
gate bars and spike kill criteria are declared in §§1–2 and §5
BEFORE any test-set judging (§3). Working files:
`~/workspace/peoplegone/phase-d-investigation/` (photos, ground
truth, detection dumps, overlays, metrics — same pattern as the
Phase A/C investigations).

**Question (plan §4 Phase D; design X12–X14):** can the worker
reliably WARN — on the Result screen, with a guided path into the
existing Brush — when a person the user removed probably left a
visible reflection behind? Reflections are never items, never
promised, and never auto-removed in v1 (X13: not promised, full
stop). The keeper's reflection is protected like the keeper (X13).

## 1. Approach + licence check (declared before judging)

**State of the art (from the expansion tech research, verified
2026-10-14):** no product or paper detects a *specific person's*
reflection, associates it with that person, and removes it. The
shipped whole-image reflection tools solve a different problem
(photos taken *through* glass) by replacing every pixel of the
frame, which is incompatible with this pipeline's untouched-original
compositing guarantee, and their own stated limits exclude small
windows, car bodies and lakes. Mirror-*region* segmentation exists
academically, but the models/datasets in that lineage have
unverified licences (plan §7) and are therefore NOT used here.

**v1 approach — built only from what already runs in the worker:**

1. **Person detections** from the existing RT-DETR pass
   (`PekingU/rtdetr_r50vd`, Apache-2.0, already in production).
2. **Reflective regions** from the existing open-vocab detector,
   OmDet-Turbo Tiny (`omlab/omdet-turbo-swin-tiny-hf`, Apache-2.0 —
   licence verified in Phase B and recorded in
   `worker/distractions.py`), prompted for reflective surfaces:
   mirror, window / glass, car body, puddle / water, polished /
   glossy floor. No new model, no new dependency.
3. **Candidate reflections:** person-shaped detections situated
   inside a reflective region, plus (for horizontal surfaces —
   water, puddles, glossy floors, where reflections are vertically
   flipped smears a person detector usually misses) geometric
   evidence directly below a removed person's feet inside a
   detected water/puddle/floor region.
4. **Association + keeper veto (the heart of the phase):** a
   candidate warns only if it associates to a REMOVED person
   (geometry per §4) and does NOT associate at least as strongly to
   a keeper. A candidate that is itself in the removed set needs no
   warning — the main pass already removes it. A reflection with no
   removed person to belong to (e.g. the photographer's own
   reflection, with nobody removed) never warns.
5. The warning is **additive `/process` meta only**. The warning
   path must never alter the composite (§2 gate 2).

**Licence position:** no new model is introduced, so no new licence
is required. OmDet-Turbo Tiny (Apache-2.0) and RT-DETR (Apache-2.0)
are already shipped in the worker image. Academic mirror
segmentation (MirrorNet/PMD lineage) remains excluded until its
licence is verified — it is not needed for this approach.

**Gateway verification (checked in code, not assumed):**
`worker-callback` stores the worker's `/process` meta object
verbatim on the job, and `job-status` returns that meta to the app
once the job is done — the same path belongings/distractions
summary fields already ride. An additive reflection-warning field
in `/process` meta therefore needs **no gateway change**. (The
`/detect`-side functions `analyse-job`/`create-job` are not
involved: the warning is a property of the confirmed removal, so it
belongs to `/process` meta, in the spirit of the ghost notice.)

## 2. Gate bars — declared BEFORE judging

Warnings must be high-precision: a warning that is usually wrong
trains users to ignore it, and then it is worse than no warning
(plan §4 Phase D gate; research §3c measures warn precision/recall
as the v1 metric; plan OQ2 sets a ≥95% measured-precision ethos for
anything user-facing in this programme).

- **Warn precision bar (hard): ≥ 0.90** across all warnings issued
  on the test set. On a bounded set this is deliberately strict:
  with ~3–6 warnings issued, a single false warning already puts
  precision at or below the bar — which is the point.
- **Recall floor (hard, declared now): ≥ 0.50** of GT-positive
  photos warned. Below half, the warning is not useful enough to
  justify a new Result-screen element. Precision outranks recall
  by design: a missed warning leaves the user exactly where they
  are today (the brush exists); a false warning spends trust.
- **Ship gate (all three, per the phase brief):** (1) precision
  meets the bar above; (2) the §5 final-composite pixel-diff
  acceptance still passes — the warning path never alters the
  composite; (3) **zero false warnings on the GT-negative control
  photos**. If the gate fails: stop, document, commit, report. Do
  not force a ship.

## 3. Test set (12 photos, owner-capped) + by-eye ground truth

Sources: the frozen test-set pack (29, 30, 13, 28), the owner's
mosque photo, and Pexels free-licence stock sourced for the missing
cases (mirror, glossy floor, water). Keeper/removed designations
refer to the DIRECT people in the frame; a reflected instance is
never itself designated a keeper or a removal — it is the thing
being predicted. GT was set by eye on the originals before any
detector output was examined.

| # | Photo | Surface | Designation | GT warn? | By-eye basis |
|---|---|---|---|---|---|
| 1 | 30_puddle_reflection | puddle (water) | keep right foreground woman; remove centre man, left woman, background people | **YES** | The foreground trio's inverted reflections fill the puddle's lower half; the centre man's reflected figure (centre, lower-middle) is unmistakable |
| 2 | px_floor_hallway | glossy floor | keep seated man (right); remove walking man (centre) | **YES** | The walking man's blue/orange reflection streaks the polished floor directly below him, full body length |
| 3 | px_salt_lake_reflection | water (salt lake) | keep left group; remove the right-side individuals | **YES** (small scale) | Short vertical reflection streaks sit in the water directly below the right-side walkers — visible but only a few % of frame height |
| 4 | px_mirror_suit | mirror | the man is the KEEPER | **NO** — keeper control | His waist-up reflection fills the fitting-room mirror; a keeper's reflection is protected (X13) and must never warn |
| 5 | px_bookstore_window | shop window | keep woman; remove man | **NO** | The couple stands before the glass; the window shows the shop interior — no person reflection is visible in it |
| 6 | 28_museum_gallery | glossy floor | keep hoodie man; remove woman at right | **NO** | Polished wood floor with light sheen only; no person's reflection is discernible in it |
| 7 | 13_metro_entrance | train body / windows | keep foreground couple; remove the rest | **NO** | The train's windows are reflective but show only light streaks and interior — no reflected person |
| 8 | owner_mosque | none | keep owner [0]; remove 12 | **NO** | Dusk crowd on stone; no reflective surface present |
| 9 | px_glossy_floor_empty | glossy floor | — (no people) | **NO** | Reflective floor mirroring pillars and light; nobody in frame |
| 10 | px_window_photographer | storefront glass | — (no direct person) | **NO** | The only figure is the photographer's own reflection in the glass; nobody is removed, so there is nothing for a warning to belong to |
| 11 | px_store_cleaner | shop window | — (no direct person) | **NO** | The figure in the glass is a reflection (street cleaner outside the gallery); no direct person is removed |
| 12 | 29_store_window | shop window | — (no direct person) | **NO** | Figures visible in/behind the glass are not reflections of any in-frame person; no removed person exists for a warning to attach to |

**Coverage gaps (honest):** only 3 GT-positive photos — clear
multi-person reflection scenes are rare in free stock, and two
sourced candidates (café/city window overlays) were dropped after
inspection because they are through-glass overlay photos (research
problem A), not in-scene reflections. Car-body reflections of a
removed person: NO sourceable case found — unmeasured, no claim
made. Recall on 3 positives is coarse (each photo = 33 points);
that coarseness is itself reported with the verdict. The salt-lake
positive is small-scale; the textbook mirror case appears only as
a keeper control because no free-stock photo with two direct
people before a mirror was sourceable.

## 4. Candidate algorithm (to be frozen after the detection pass)

Detection dumps (RT-DETR persons + OmDet reflective-region and
reflection prompts) are gathered first; the association rules are
then written here, frozen, and only then judged against §3.
Iterations, if any, are recorded in §6 with the numbers that
motivated them — the frozen version is what the gate judges.

## 5. Reflective-surface auto-removal spike — kill criteria (declared BEFORE running)

Per the amended plan, a timeboxed spike may try automatic removal
for the reflective-surface cases. It is bounded as follows:

- **Timebox:** one investigation block; at most 3 iterations;
  attempted on the GT-positive photos only.
- **Only allowed method:** candidate region from the frozen §4
  logic → SAM mask from the candidate box → the existing pipeline
  inpaint + feather composite onto the untouched original. No
  whole-image layer separation (incompatible with the compositing
  guarantee), no new model.
- **It dies unless it beats warn-only:** for EVERY attempted
  positive, the reflection must be no longer visible by eye at the
  would-post bar, with no new visible artefact.
- **Protected pixels:** the candidate mask is clipped against the
  protected set (keeper persons + keeper-associated reflection
  regions); the §5 pixel-diff acceptance must pass on the spike
  outputs — any protected-pixel change kills the spike.
- **Association floor:** if the §4 association precision on the
  positives is below the §2 precision bar, the spike dies
  immediately (removing the wrong region is worse than warning).
- If it dies, reflections remain a brush case permanently for v1,
  and the honest record of why is a successful deliverable.

## 6. Results

_(To be filled as the investigation runs.)_
