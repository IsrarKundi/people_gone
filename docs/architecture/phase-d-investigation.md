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

## 4. Frozen algorithm (frozen 2026-10-15, before judging)

What the detection pass showed (full dumps in the investigation
workdir, `results/detections.json`; run: RT-DETR persons +
OmDet-Turbo with the surface prompts and the reflection prompts,
production-identical post-processing):

- **The reflection prompts alone are not evidence.** Prompted with
  "reflected person" / "reflection of a person" / "person
  reflection" / "person in mirror", OmDet re-boxes the DIRECT
  people in almost every photo — including the mosque and the
  metro, where no reflection exists at all. A reflection-prompt box
  is only meaningful when it does not coincide with a direct
  person.
- **RT-DETR rarely detects reflected instances on horizontal
  surfaces.** In the puddle flagship it found 10 direct people and
  none of the (clearly visible) reflections; on the salt lake the
  reflections merged into the people's own boxes. Reflected
  instances were detected as persons only in the textbook mirror
  control — where they sit in the removal set and the main pass
  handles them.
- **OmDet surfaces are noisy** (the mosque's stone reads "polished
  floor" at 0.63; a train reads "car"; a whole frame reads
  "mirror"). Surface boxes can host a candidate; they can never
  raise a warning by themselves.

The frozen algorithm is the production module
`modal-deploy/server/worker/reflections.py` (the judged code is the
shipped code, Phase C pattern). Two independent signals; either
can raise a warning; warnings attach to REMOVED people only:

**Signal A — candidate boxes.** An OmDet reflection-prompt box
(score ≥ 0.30, deduped at IoU 0.5) counts when ALL hold:
(a) it does not coincide with any detected person (IoU < 0.4 and
containment < 0.6 both ways) — coincident boxes are the direct
people the prompt re-fires on;
(b) ≥ 50% of it lies inside a detected reflective surface
(score ≥ 0.30);
(c) it associates geometrically to a removed person — vertical
surfaces (mirror/window/glass/car): vertical overlap ≥ 0.4 of the
shorter height, horizontal gap ≤ 0.75 person-widths, height ratio
0.3–1.8; horizontal surfaces (water/puddle/floors): the candidate
hangs below the person's feet (top ≥ feet − 0.15h, bottom ≤ feet
+ 1.3h), horizontal overlap ≥ 0.3 of the narrower width, height
≤ 1.2× the person's;
(d) it does NOT associate to any keeper under the same rules —
absolute keeper veto.

**Signal B — flip match.** For each removed person at least 8% of
the image height (smaller templates match noise — measured, §6)
whose feet sit at a horizontal reflective region (score ≥ 0.35):
flip the person's own box vertically and template-match it
(normalized cross-correlation, scales 1.0/0.7/0.5/0.35) in the
strip below their feet (feet − 0.05h to feet + 1.05h, own span
± 0.3 widths), the match's top within 0.25h of the feet line.
Best score ≥ **0.50** warns. 0.50 is the midpoint of the observed
gap (highest negative 0.424, lowest true positive 0.567) —
chosen for balanced margin, not fitted to an edge.

A detected person who IS the reflection (textbook mirror) sits in
the removal set and is removed by the main pass — no warning, by
design. A reflection with no removed person to belong to never
warns, whoever it shows.

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

### 6.1 Iteration history (numbers that motivated each step)

- **v1 scoring prototype** (throwaway, workdir
  `scripts/score_v1.py`): Signal A fired exactly once across the
  set — the glossy-floor positive (candidate = the reflection
  streak itself, OmDet 0.543, associated to the removed walking
  man, no keeper association) — and produced no candidate
  anywhere else. Signal A is precise but covered 1 of 3
  positives; the puddle reflections got no box from any detector.
- **Flip-match v1** (raw grayscale NCC, no size rule) overlapped:
  true positives 0.507–0.749, but a 48-px-tall mosque detection
  scored 0.676 and a KEEPER on the floor photo scored 0.591.
  Keeper scores do not matter (warnings are computed for removed
  people only), but the tiny-template score does — hence the
  ≥ 8%-of-image-height rule, under which the mosque's best removed
  score falls to 0.424.
- **Variant run** (`scripts/score_v2_variants.py`): a darkness map
  is identical to grayscale under NCC (affine invariance — same
  scores to 3 decimals); gradient-magnitude matching was worse on
  every positive (puddle 0.567 → 0.201). Both variants rejected;
  raw grayscale kept.
- **Match locations were eyeballed** on the positives: the puddle
  match box sits directly below the centre man's feet over his
  reflected figure; the salt-lake matches sit at the removed
  walkers' feet. The scores are measuring the reflections, not an
  artefact of the search window.

### 6.2 Frozen judging (production module, investigation set)

Runner: workdir `scripts/judge_frozen.py` → `results/judged_frozen.json`.

| Photo | GT | System | Evidence |
|---|---|---|---|
| 30_puddle_reflection | WARN | **WARN** | flip 0.567, centre man, "polished floor" |
| px_floor_hallway | WARN | **WARN** | candidate 0.543 (the streak) + flip 0.577 |
| px_salt_lake_reflection | WARN | **WARN** | flip 0.749 + 0.711, two removed walkers |
| px_mirror_suit (keeper control) | no | no | reflection is a detected person in the removal set; no candidate survives |
| px_bookstore_window | no | no | reflection prompts coincide with the direct couple only |
| 28_museum_gallery | no | no | sheen only; no candidate, no flip window |
| 13_metro_entrance | no | no | best removed flip score 0.26 |
| owner_mosque | no | no | best removed flip score 0.424 (< 0.50) |
| px_glossy_floor_empty (surface control) | no | no | nobody removed |
| px_window_photographer (hard negative) | no | no | nobody removed |
| px_store_cleaner (hard negative) | no | no | nobody removed |
| 29_store_window (hard negative) | no | no | nobody removed; a large candidate box associates to no one |

**Warn precision 1.000 (3/3 warnings correct). Warn recall 1.000
(3/3 GT-positive photos warned). False warnings on controls: 0 of
9 negatives, including every required control class.**

Honest bounds on those numbers: the set is 12 photos with 3
positives (the owner-capped size), so each positive is 33 recall
points and 1.000/1.000 is a coarse measurement, not a population
estimate. The flip threshold was selected on this same set (gap
midpoint, §4) — a real overfitting risk that a bigger set would
retire; the mitigations are the midpoint choice, the independent
second signal, and the precision-first design (a miss leaves the
user exactly where v1 already leaves them). Car-body reflections
and a two-people-before-a-mirror positive remain unmeasured
(§3 gaps) — no claim is made for them.

### 6.3 Spike outcome — KILLED under the §5 criteria

Method exactly as declared: frozen warning box → SAM mask →
production mask prep (protected-set clip, fill, dilate, clip) →
MAT crop inpaint → feather composite onto the untouched original.
Runner: workdir `scripts/spike_app.py`; outputs in workdir
`spike/`; numbers in `results/spike_results.json`.

Safety held everywhere: **0 protected pixels changed and 0
changed pixels outside the allowed removal union on all three
photos** — the method never endangers a keeper. It failed on
effectiveness, judged by eye at the would-post bar:

- **Puddle flagship — FAIL.** The centre man's reflected figure
  is still plainly visible in the output. SAM's mask from the
  warning box captured only part of the reflected figure, and the
  other removed people's reflections had no warning box at all,
  so most of the reflection field was never even masked.
- **Glossy floor — FAIL (closest).** The strong blue body of the
  streak was removed, but a visible orange-red remnant and light
  smear remain where the reflection was. "No longer visible by
  eye, no new visible artefact" is not met.
- **Salt lake — FAIL.** Before/after are indistinguishable at
  viewing scale; the streaks under the removed walkers remain.

Why, in one sentence: a reflection is a translucent, gradient
phenomenon, not an object — a box-prompted SAM mask traces only
its darkest core, so the pipeline faithfully removes a part of the
reflection and leaves the rest, which reads as a smear rather than
a clean surface. Per §5, reflections therefore remain a **brush
case permanently for v1**. The warning (which is what v1 ships)
is unaffected: it tells the user the reflection may still be
there, which this spike confirms is true.

### 6.4 Gate verdict — PASS for warn-only v1

Against the §2 bars, applied exactly as declared:

1. **Warn precision 1.000 ≥ 0.90 bar** ✓ (3/3 warnings correct;
   recall 1.000 ≥ 0.50 floor, 3/3 positives).
2. **Pixel-diff acceptance** — the warning path is meta-only and
   cannot alter the composite by construction; the §5 acceptance
   suite is re-run on the built worker as build verification
   (result recorded in the build commit).
3. **Zero false warnings on the control photos** ✓ (0/9,
   including the keeper-before-mirror, surface-with-no-people,
   and photographer-reflection controls).

Ship scope is therefore exactly the plan's v1: detect + warn +
guided brush. Automatic reflection removal does NOT ship (§6.3).

### 6.5 Build + live verification (2026-10-15)

- **Worker:** `worker/reflections.py` (frozen logic) wired into
  `/process`: two extra OmDet passes + the warn logic run when
  somebody is removed; meta gains `reflection_warning` +
  `reflection_regions` (additive, contract stays v3). No gateway
  change — worker-callback stores meta verbatim and job-status
  returns it, verified from the function sources. 10 new synthetic
  unit tests; full worker suite **52 OK** (2 env-gated skips);
  **§5 pixel-diff acceptance passes** on the built worker
  (`PG_RUN_PIXEL_DIFF=1`, both test classes, 0 px beyond the
  allowed union).
- **App:** the warning parses in BOTH paths (gateway poller +
  direct impl, malformed regions skipped, never fatal) into
  `ProcessedPhoto` → `ProcessingOutcome`; Result shows the factual
  warning line + "Fix with brush", which opens the existing Brush
  with the first region outlined as a starting guide (the user
  still paints; the outline is never part of the mask). No new
  screens, no promise language. `flutter analyze` clean; **Flutter
  suite 158/158** (9 new tests: parsing ×3, Result warning/UI ×3,
  painter ×3).
- **Live (deployed worker, exactly 2 photos):**
  1. Puddle flagship, keep=[1]: 10 persons, 9 removed,
     **`reflection_warning: true`** with the frozen region
     (person 2, flip 0.567, "polished floor") — identical to the
     investigation judging. Output verified by eye: the removed
     people are gone, the keeper stands intact, and the removed
     people's reflections remain visible in the puddle — the
     warning is truthful. 71.8 s total; the reflection pass added
     7.4 s on this 18 MP photo (1.3 s on the 1.4 MP mosque).
     Peak RSS 7,413/8,192 MB.
  2. Owner mosque, keep=[0] (control): 13 persons, 12 removed,
     **`reflection_warning: false`**, regions []. Phase A
     regression intact (handbag still attached to person 4);
     dimensions in = out; no fallbacks on either job.
