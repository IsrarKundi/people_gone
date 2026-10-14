# Phase C investigation — shadow cleanup v1 (directional growth)

**Status:** investigation complete at mask level; blind A/B + gate
verdict in §6 (filled after the A/B run). Working files:
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

1. **Floor first.** The production heuristic runs unchanged; v1 only
   ADDS pixels.
2. **Estimation pool** (relative-dark, wider than the floor's test):
   S<140 ∧ V<200 ∧ V < 0.80×local V, minus all person masks.
3. **Per-person samples:** the connected pool blob touching the
   person's dilated mask, clipped to a disc of radius 1.3×height
   around the feet anchor; valid only if the blob passes through the
   contact strip just below the feet (every real cast shadow starts
   there; scenery blobs touching a person's side/head do not), its
   centroid sits at/below feet − 0.35×height, and its length
   ≥ 0.08×height.
4. **Photo direction:** length-weighted mean of sample directions,
   gated hard — agreement ≥ 0.5, longest sample ≥ 0.25×height, and
   (median length ≥ 0.15×height OR ≥ 3 samples); a LONE sample is
   trusted only if it points clearly downward (dy ≥ 0.3). Any doubt
   → no direction → the photo is prepped by the floor alone.
5. **Directional growth:** per removed person, direction = own sample
   blended 2:1 toward the photo direction (perspective: shadows are
   parallel in the world, not in the image); corridor = fan of three
   constant-width sweeps of the mask's lower-40% slice at
   direction ± 0.14 rad, up to 2.5×height (ground shadows) or
   0.6×height (upward samples — wall case); additions = corridor ∩
   growth pool (S<140 ∧ V<210 ∧ V < 0.85×local V) ∩ NOT protected,
   capped at 3.0× the person's mask area, nearest-first.
6. **Absolute veto:** the protected set = every keeper's
   hole-filled halo ∪ every keeper's own observed shadow blob.
   Additions never enter it; a keeper's final mask is byte-identical
   to production behaviour.

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

_TBD — filled after the stage-4 run and blind judging._
