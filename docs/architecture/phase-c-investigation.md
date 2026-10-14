# Phase C investigation — shadow cleanup v1 (directional growth)

**Status:** COMPLETE — gate PASSED (§6), integrated and shipped
(worker `shadow_mode="v1"` default). Working files:
`~/workspace/peoplegone/phase-c-investigation/` (photos, GT,
overlays, metrics, A/B outputs — same pattern as the Phase A
investigation). Prototype: `scripts/shadow_v1.py`; measurement
harness: `scripts/stage3_measure.py`; blind A/B:
`scripts/stage4_ab.py`.

**Question (plan §4 Phase C):** can mask preparation grow a removed
person's mask DIRECTIONALLY along the photo's estimated light
direction — beyond the current below-the-feet search box — to catch
side/long shadows, with an absolute keeper veto, no new model, and
no new user-facing claims (design X12–X14)?

## 1. What production does today (the floor)

`worker/mask_prep.py::expand_shadows` adds pixels that pass
V<130 ∧ S<140 AND are connected to the person's mask, searched ONLY
inside a box = the person's box widened ±30%, from 20% above the feet
to 60px below them. Anything outside that box — every long evening
shadow, every side shadow — survives removal by construction.

## 2. Test set (7 photos, owner-capped)

Built from the frozen test-set pack + the owner's mosque photo.
Keeper sets were set by hand per photo (production heuristic keeper
in parentheses where it differed — the heuristic is a placeholder,
the hand call is the investigation's truth):

| Photo | Light | Keepers (GT) | Role |
|---|---|---|---|
| 22_sunset_sidewalk (4413×5516) | sunset, shadows ~2.5–3× person height toward camera | central couple [0,1] | FLAGSHIP — the case v1 exists for |
| 10_tiled_piazza (4423×6635) | golden hour, soft streaks down-right | foreground couple [0,1] | faint low-contrast shadows on bright tile |
| 21_sunny_promenade (6016×4000) | noon, short pools displaced down-left | foreground pair [0,1] (heuristic kept [8]) | midday pools — the floor's home turf |
| 08_historic_arch (2796×4210) | B&W, long streaks in a sun patch + deep shade | foreground woman [0] (heuristic kept mid-ground men) | stress: texture/shade chaos |
| 01_beach_solo (3648×5472) | beach, keeper casts a long clear shadow | solo woman [0] | keeper-safety only (removed tourists are 19–89px; their shadows are below annotation scale) |
| 23_street_lamp_shadow (3000×2000) | night neon, multi-source diffuse | man [0] | CONTROL — no directional cast shadow exists; the estimator must stay quiet |
| owner_mosque (900×1600) | dusk crowd, dark ground patches are stains/wet stone | owner [0] | safety only — no attributable cast shadows |

Dropped after inspection (recorded, not hidden): 03 (file deviates
from manifest; single person, no cast shadow), 04 (backlit, no cast
shadows), 07 (persons tiny, shadows negligible), 12 (ground occluded
by crowd), 25 (hazy, tiny people), px_luggage_street (diffuse, no
shadow), px_bench_couple (seated close-up, no shadows).

**Coverage gap (honest):** NO sourced photo shows a person's shadow
cast ON A WALL. The v1 growth is surface-agnostic in image space (it
grows along the estimated direction wherever the candidate test
passes), so wall shadows along the direction would be treated like
ground shadows — but that is UNMEASURED and stays labelled as such.

## 3. Ground truth

Per photo, hand-drawn polygons (0–1000 relative coordinates, pinned
against coordinate-grid overlays) around each removed person's cast
shadow and each keeper's cast shadow, intersected with a
relative-darkness soft map (V<175 ∧ S<170 ∧ V < 0.75×local-blurred V)
and with the complement of all person masks. GT therefore measures
the *dark core* of each shadow. An earlier component-labelling GT
was abandoned: absolute thresholds merge whole backlit scenes into
mega-components, and the relative map fragments into 192–316
components per photo — unlabellable by hand. GT file:
`ground_truth.json` in the working folder.

## 4. The v1 algorithm (as frozen after 4 iterations)

Faithful description of the frozen prototype
(`scripts/shadow_v1.py`), which the production port reproduces
bit-for-bit (equivalence evidence in §6).

1. **Floor first.** The production path runs unchanged
   (fill holes → dilate → `expand_shadows`); v1 only ADDS pixels.
2. **Pools** (both locally-dark, low-saturation; local V = blur with
   a width-relative kernel, k = max(15, 1.5% of image width)):
   estimation pool V<200 ∧ S<140 ∧ V < 0.80×local V; growth pool
   V<210 ∧ S<140 ∧ V < 0.85×local V. Uniform shade masses and dark
   interiors are locally uniform and drop out of both.
3. **Per-person samples:** for each person, the estimation-pool
   component connected to their mask inside a generous search region
   around their box (±60% width, +35% height above, +100% below),
   excluding all person interiors; the blob is clipped to a disc of
   radius 1.3×height around the mask's feet anchor before its
   centroid is taken (a merged group pool otherwise drags every
   member's centroid sideways). A sample is valid only if: blob
   ≥ 200px; centroid at/below feet − 0.35×height; the blob passes
   through the contact strip just below the feet (every real cast
   shadow starts there; scenery blobs touching a person's side/head
   do not); length ≥ 0.08×height.
4. **Photo direction:** area-weighted circular mean of the valid
   samples, hard-gated — agreement ≥ 0.5, longest sample
   ≥ 0.25×height, and (median length ≥ 0.15×height OR ≥ 3 samples);
   a LONE sample is trusted only if it points clearly downward
   (dy ≥ 0.3). Any doubt → no direction → the photo is prepped by
   the floor alone.
5. **Per-person growth direction:** the person's own sample blended
   toward the photo direction (own weight 2 if the sample is solid,
   len ≥ 0.25×height, else 1:1) — shadows are parallel in the world,
   not in the image (perspective); a person without a sample uses
   the photo direction.
6. **Directional growth:** corridor = fan of three constant-width
   sweeps of the DILATED mask's lower-40% slice at direction
   ± 0.14 rad, length ≤ 2.5×height, computed in a window around the
   person. Additions = corridor ∩ growth pool ∩ not-any-person,
   restricted to the component connected to the person, minus the
   protected set, area-capped at 3.0× the person's mask area
   (nearest-first along the direction).
7. **Absolute veto:** the protected set = every keeper's
   hole-filled halo ∪ every keeper's own observed shadow blob (the
   estimator sample blob when one exists, else the raw observed
   blob). Additions never enter it; keepers never appear in the
   prep output, as in production today.

No new model, no new dependency (numpy/opencv only — both already
in the worker image).

## 5. Iteration history (mask-level, measured identically)

- **It. 1** (global direction from the floor's own blobs; full-
  silhouette corridor; floor's candidate test): FAILED instructively
  — direction pointed UP on 5/7 photos (the biggest "shadow" blob
  near most people is scenery: shade masses, dark façades); 08 grew
  841k px, ~827k of them unattributed shade interior.
- **It. 2** (per-person blended directions, relative-dark growth
  pool, area cap, keeper-blob protection): 22 recall 0.071 → 0.480,
  keeper incursions ZERO everywhere; but 23 (control) still grew
  15.9k scenery px, 08 recall only 0.200 with 16k mostly-junk px,
  piazza/beach estimators found no valid samples in the floor's pool.
- **It. 3** (relative estimation pool, disc clip, stricter photo
  gate, fan corridor): 22 recall → 0.871; 23/mosque/beach fully
  quiet; BUT piazza direction still flipped up (one/two samples from
  scenery connected to mid-ground people) and grew 21.7k junk px.
- **It. 4 = FROZEN** (contact-strip rule + lone-sample downward
  rule): piazza quiet. Final numbers:

| Photo | Direction | Recall old → new | Keeper damage old → new | Additions into keeper body / shadow | Additions total (into GT / unattributed) |
|---|---|---|---|---|---|
| 22_sunset_sidewalk | (−0.31, +0.95), agree 0.94, n=3 | **0.071 → 0.871** | 0 → 0 | 0 / 0 | 24,090 (5,900 / 18,190) |
| 10_tiled_piazza | none (gate) | 0.076 → 0.076 | 0 → 0 | 0 / 0 | 0 |
| 21_sunny_promenade | none (gate) | 0.229 → 0.229 | 0 → 0 | 0 / 0 | 0 |
| 08_historic_arch | none (agree 0.09) | 0.179 → 0.179 | 0 → 0 | 0 / 0 | 0 |
| 01_beach_solo | none | — (safety only) | 0 → 0 | 0 / 0 | 0 |
| 23_street_lamp | none | — (control) | 0 → 0 | 0 / 0 | 0 |
| owner_mosque | none | — (safety only) | 0 → 0 | 0 / 0 | 0 |

Pooled recall over GT-bearing photos: 0.147 → 0.224 (the pooled
figure is dominated by the three photos where v1 deliberately stays
quiet and new ≡ old; on the one photo with measurable long shadows
the gain is 0.071 → 0.871).

**Reading of the mask-level result, honestly:**
- The flagship case (long ground shadows toward/along the camera) is
  decisively fixed at mask level, with ZERO measured keeper
  incursion on any photo — the veto held under every iteration.
- On faint shadows on bright ground (piazza) v1 does nothing:
  direction evidence never stabilised (scenery keeps impersonating
  shadow evidence for small/distant people), and the estimator's
  answer is silence rather than a guess. The floor's 0.076 stands.
- Noon pools (21): silence again (two weak samples disagreed) — no
  gain, no harm.
- B&W (08): silence; pixel tests cannot separate cast shadow from
  cobble texture there. No gain, no harm.
- KNOWN LIMIT even on 22: growth takes the shadow's dark CORE; the
  visible streak's softer flanks are warmer/more saturated than the
  growth pool admits (overlay evidence in the working folder). The
  A/B (§6) is the instrument that decides whether the remaining
  flanks fail the would-post bar.

## 6. Blind A/B + gate verdict

**Method:** for each test photo, both arms cleaned with the
production per-person crop pattern + production MAT inpainting +
4px feather composite (ghost check deliberately not run in either
arm — identical downstream machinery; the A/B isolates mask prep).
A/B assignment by seeded coin flip; verdicts written to
`ab/ab_judgements.json` BEFORE the key (`ab/ab_key.json`) was
opened. Judged on shadow completeness + keeper safety at the
would-post bar.

| Photo | Blind verdict | Unblinded |
|---|---|---|
| 22_sunset_sidewalk | **A better, decisively** — B removes the walker but leaves their ENTIRE long shadow streak orphaned on the pavement; A removes person + streak; keepers and their shadows intact in both | A = **new**, B = old |
| 10_tiled_piazza | tie — no visible difference; couple + their shadow band preserved in both | A = new |
| 21_sunny_promenade | tie — arms identical; keepers' foot pools preserved | A = old |
| 08_historic_arch | tie — both arms poor on the mid-ground removals (pre-existing fill failure on this photo, known since the Phase 0 CPU run); no arm better on shadows, none worse on safety | A = new |
| 01_beach_solo | tie — keeper pristine in both; her long sand shadow FULLY intact in both (the veto case, visually confirmed) | A = old |
| 23_street_lamp_shadow | tie — control clean; no spurious dark-region eating in the neon scene | A = old |
| owner_mosque | tie — keeper + his ground shadow intact in both; left-cluster fill smears in both (known large-cluster fill weakness) | A = old |

**Gate (§5) — PASS:**
1. *Zero protected-set damage:* the final-composite pixel-diff
   acceptance test passes with the new mask prep in the loop
   (`PG_RUN_PIXEL_DIFF=1`, both classes — belongings mosque case +
   distraction bus case — 2 tests OK, 178.6s, run against the
   integrated production code). Mask-level: additions into keeper
   bodies / keeper shadows = 0 px on all 7 photos; keeper-shadow
   damage 0 → 0 everywhere.
2. *Blind A/B:* new wins or ties on shadow completeness on every
   photo (1 decisive win, 6 ties) and NO photo is worse on keeper
   safety.

**Integration (shipped):**
- `worker/shadow_growth.py` — faithful production port of the
  frozen prototype; `worker/mask_prep.py` —
  `prepare_individual_removal_masks(..., shadow_mode="v1")`
  (default) with `"legacy"` = the exact pre-Phase-C path, chosen
  explicitly via `PipelineConfig.shadow_mode`; unknown modes raise.
  No silent fallback anywhere.
- **Equivalence proof:** production port vs investigated prototype
  masks = **0 px difference** on 22 / 10 / 21 / mosque; legacy mode
  vs the stage-3 floor masks = **0 px difference**. The gate
  evidence above therefore applies to exactly the shipped code.
- **Tests:** new `tests/test_shadow_v1.py` (7 synthetic-scene
  tests: estimator direction, growth beyond floor, keeper veto,
  quiet-scene v1 ≡ legacy, legacy ≡ hand-rolled floor, area cap,
  unknown-mode raise). Full worker suite: **42 tests OK** (2
  env-gated skips) from `modal-deploy/server/`.
- No contract change, no app change (X12–X14: shadows are not
  items; copy frozen), no Phase B shipped-set change, no new
  dependency.

**Live verification (deployed worker, bounded to exactly the two
agreed photos):** redeployed from `modal-deploy/` after the gate
pass. (1) Owner mosque photo, keep=[0]: ok, 13 persons, keeper [0],
12 removed, the Phase A handbag still detected attached to person 4
(box/score byte-identical to the pre-Phase-C build — no regression),
900×1600 in = out, total 130.9s (mask_prep 0.32s), no fallbacks.
(2) 22_sunset_sidewalk, keep=[0,1]: ok, walker (id 2) removed,
4413×5516 in = out, total 16.9s warm (mask_prep 2.3s at 24MP), no
fallbacks; visually verified — **the walker's long shadow streak is
gone from the deployed output and the keepers' shadows are fully
preserved** (evidence in the working folder, `live/`).

**Known limits (carried honestly):** v1 fires only where cast
evidence is strong — faint shadows on bright ground (piazza),
midday pools (promenade), and B&W texture chaos (arch) stay at the
floor's coverage until a future phase brings better evidence
extraction (Phase E territory). Wall shadows remain UNMEASURED
(no sourceable test photo; growth is direction-based and
surface-agnostic in image space, so they would be treated like
ground shadows along the same direction — a claim this
investigation does not make).
