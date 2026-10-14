# Removal Expansion — Implementation Plan (Distractions · Belongings · Shadows/Reflections)

**Date:** 2026-10-14
**Status:** PLAN ONLY — no code written. **Owner decision 2026-10-14: direction APPROVED; Phase A investigation approved; every phase ships only after passing its test gate — no phase is pre-approved, and phases are not started in parallel.** Amendments from the owner's review (same date) are folded into §4 Phase A (association tiers tightened), §4 Phase D (reflective-surface spike), and §5 (final-composite pixel-diff acceptance test).
**Inputs:**
- Code review of the shipped pipeline (this plan, §1) — verified from `modal-deploy/` source.
- Technical research: `~/workspace/research_notes/peoplegone-removal-expansion-tech-resear-20261014-1512/report.md` (claims labelled Observed vs Inference there; figures quoted here keep those labels).
- Design: `docs/design/DESIGN_expansions_integration.md` — rulings X1–X19, open questions OQ1–OQ8 (answered in §3 of this plan).
- Binding rules: `PEOPLEGONE_REQUIREMENTS.md`, `AGENTS.md` (no AGPL models; keeper pixels never touched; no silent fallbacks; copy claims only what evidence supports).

---

## 1. Where we start — the current pipeline (verified from code)

1. **Detect:** RT-DETR (`PekingU/rtdetr_r50vd`, COCO-trained, Apache-2.0) — the pipeline uses **persons only**, confidence 0.35.
2. **Segment:** SAM 2.1 hiera-tiny cuts a mask per detected box.
3. **Keeper:** heuristic, or explicit keep IDs from the Proposal screen.
4. **Mask prep (per removed person):** hole fill → dilate (2% of person height, min 8px) → **shadow heuristic**: dark (V<130) + low-saturation (S<140) pixels *connected to the mask*, searched **only** in the lower 20% of the box + 60px below the feet, ±30% width. No side shadows, no wall shadows, **no reflection handling anywhere in the codebase**.
5. **Inpaint:** per-person native-res crops — MAT (default), LaMa (selectable), `auto` races PowerPaint on large crops — feather-composited (4px) onto the untouched original.
6. **Ghost check:** the person detector re-runs on finished crops; a person-shaped residual triggers one retry at 5% dilation.
7. **Flow:** pick → consent → `POST /detect` (persons only) → S4 Proposal (review + confirm) → gateway job → S6 → S7 (save consumes one save; S5 brush is the leftover-fix path).
8. **Known gaps this plan closes:** belongings survive unless the person mask happens to cover them (the floating-bag defect); shadows outside the below-feet search box survive; reflections always survive.
9. **Compute reality:** Modal CPU container (4 cores / 8GB), ~2 min/photo today. Requirements cost ceiling ≈ $0.006–0.01/photo at scale.

## 2. What the research established (headlines)

- **Belongings are nearly free.** COCO already includes backpack, handbag, suitcase, umbrella — the existing RT-DETR pass can return them; SAM masks them the same way. No "owned-object" model/dataset exists; HOI detection is too weak to gate on (~29–32 mAP, boxes only). Association must be **rules**: tiered, with a keeper-proximity veto. Stroller is **not** a COCO class.
- **Distractions split in two.** COCO covers vehicles, traffic light, stop sign, parking meter, bench, fire hydrant. It has **no bin, pole, generic sign, wire, or stroller class** — those need an open-vocabulary detector. Recommended: **OmDet-Turbo Tiny (Apache-2.0)** for CPU (est. +4–12s/photo — *estimate, no published CPU benchmarks exist*), **Grounding DINO Tiny (Apache-2.0)** as the GPU-era default. YOLO-World is **excluded** (GPLv3 / AGPL-3.0 distribution). Florence-2 not recommended as the detector (34.7 zero-shot COCO mAP).
- **Wires are a segmentation problem, not detection.** Per Chiu et al. (CVPR 2023, Adobe): wires vanish on downsampling; their method is two-stage global+local with tile inpainting; cross-dataset IoU collapses to ~19–43. Adobe ships **no weights** (test data only) → wires mean training our own lightweight segmenter, est. +30–120s/photo on CPU (breaks the cost/time envelope) vs ~2–6s on T4. **Wires are GPU-gated / opt-in in this plan.**
- **Shadows: the problem is association, not detection.** Shadow detection is benchmark-mature, but a global shadow pass (Samsung's shape) would erase keepers' shadows — forbidden by the protected-set rule (X11/X13). SOBA/LISA formulate object↔shadow pairing (1,000 photos / 3,623 pairs). Recommended v1 uses **no new model**: estimate the photo's dominant light direction from all detected people's shadows, grow the removed person's mask directionally, keeper veto. v2 (learned lightweight detector, SDDNet-class) is gated on **license verification** — MTMT/SDDNet/FSDNet/LISA code licenses were **not verified** in research and are unshippable until checked.
- **Reflections: no automatic person-reflection removal exists anywhere.** Adobe's Reflection Removal is full-frame, non-generative layer separation that replaces the whole image's pixels — incompatible with this pipeline's untouched-original compositing — and explicitly fails on small/far windows, car bodies, and lakes. Academic SIRR models share the whole-image problem. Mirror-region segmentation exists (IoU ~0.79–0.85) but nobody detects/associates a *specific person's* reflection. **Credible v1 = detect + warn + guided brush** (into the existing inpaint path), plus handling textbook mirrors via person detections inside mirror regions (which also fixes ghost-check false alarms on reflections).
- **GPU economics:** a T4 instance (g4dn.xlarge ≈ $0.526/hr, Vantage) means the $0.006–0.01/photo target buys only ~41–68s of *fully packed* GPU time — utilisation, not unit price, decides viability later. Nothing in Phases A–D requires the GPU.

## 3. Design open questions — answered

| OQ | Answer |
|---|---|
| **OQ1 Categories** | Launch set from COCO: car, bus, truck, motorcycle, bicycle, traffic light, stop sign, parking meter, bench, fire hydrant. Open-vocab adds bin, pole, sign (prompted). Per-category precision is measured in Phase B calibration; any category under the precision bar merges into "Other" or is withheld (X1/X6). Wires are not a launch category (GPU-gated, §2). Stroller: open-vocab prompt candidate in Phase B, ships only if it calibrates. |
| **OQ2 Thresholds** | Set from measured precision on the expansion test set (§5), never picked. Distraction show-threshold targets ≥95% measured precision per category (X6: below it, the item does not exist in the UI). |
| **OQ3 Association** | Tiered rules return three states — attached / ambiguous / none — so **X10 works as written** (no fallback needed): Tier 1 = belongings mask overlaps the person's dilated halo → attached. Tier 2 = contact/proximity with exactly one plausible owner → attached (lower confidence, still shown as attached, detachable per X9). Tier 3 = ground-placed or multi-candidate → **ambiguous → object chip, default Keep**. A keeper-proximity veto runs before any attachment to a removed person. |
| **OQ4 Shadows** | Yes — beyond below-the-feet: Phase C grows the mask along the photo's estimated light direction (covers long side shadows; wall/furniture shadows partially — bounded by the directional region, stated honestly). The X13 claim freeze stands until blind evidence exists. |
| **OQ5 Reflections** | No automatic handling exists or is planned for v1. Phase D = detect + warn + guided brush only. X13's "not promised" remains the standing state. |
| **OQ6 Contract** | Analysis response becomes **Contract v3 (additive)**: `items[]` entries `{kind: person\|distraction\|belonging, category, box, score, person_id?, association_tier?}` alongside the existing v2 person fields. Old clients ignore unknown fields; gateway functions pass the payload through (jobs already store meta as JSON — no migration); confirm carries `remove_item_ids` + detached belonging IDs. Versioned per `API_CONTRACT.md` practice. |
| **OQ7 Thin-structure fill** | Deferred with wires (GPU-gated). The pole-crossing-the-keeper case ships in Phase B's test set regardless: protected-set compositing guarantees keeper pixels by construction, and the test proves it. |
| **OQ8 Cost/time** | Phase A ≈ +0s (same detector pass, a few more SAM masks). Phase B ≈ +4–12s (estimate) + inpaint time for included items only. Phase C ≈ +0–2s (heuristic math). Phase D ≈ +1–3s when mirrors are present. The "~2 minutes" S6 expectation stands for the CPU feature set; if measured p95 job time grows >20% on the expansion test set, expectation copy is re-derived before launch (standing rule). |

## 4. The phases (in order; each independently shippable, each gated)

### Phase A — Belongings (ship first; ~zero added compute)
**Worker** (`modal-deploy/server/worker/`):
1. `detector.py`: return COCO belongings classes (backpack, handbag, suitcase, umbrella; bicycle as a candidate class) alongside persons from the same RT-DETR pass.
2. `segmentor.py`: SAM masks for belongings boxes (same path as persons).
3. New `belongings.py` (mask prep): tiered association, keeper-proximity veto, per-person attached lists + ambiguity flags. **Tier rule (tightened 2026-10-14):** automatic attachment requires the belonging's mask to be contiguous with / overlapping **exactly one** person's dilated halo and no other person's. Mere proximity or contact is never sufficient for automatic attachment, and **anything touching two people is ambiguous by construction** (→ object chip, default Keep, per X10). This is the stranger-standing-beside-the-keeper case: a keeper's held bag near a removed person must never auto-attach to the removed person.
4. `pipeline.py`: attached belongings' masks union into their person's removal mask *before* dilation/shadow prep; `detect()` returns belongings + association tiers; ghost check extended to re-detect belongings classes in finished crops (a surviving bag retries like a surviving person).
5. Contract v3 fields for belongings (OQ6).
**Gateway:** analyse/confirm payloads pass the new fields through; no schema migration (meta JSON).
**App:** S4 person chip gains the "Includes: …" line with tap-to-detach (X9); canvas draws attached belongings joined to their person (X9a); ambiguous belongings render as object chips in the Distractions group shell (X10) — *the group container + object chip ship in this phase, driven only by ambiguous belongings until Phase B.*
**Gate (§5):** staged-ownership test set; **zero keeper-belonging damage**; attached-belonging removal success ≥ people-removal bar on the same photos.

### Phase B — Distraction objects
**Worker:**
1. Benchmark spike (first step, timeboxed): OmDet-Turbo Tiny on the actual Modal CPU container against the expansion test set — the +4–12s figure is an estimate with no published CPU benchmark behind it; measure before committing.
2. `detector.py` gains a second pass (open-vocab prompts: bin, pole, sign, stroller + the COCO launch set from the existing pass).
3. Per-category precision calibration → the show list (OQ1/OQ2); categories below the bar are withheld server-side, never shown weak.
4. `pipeline.py`: confirmed distraction items inpaint like person crops (same native-res crop path); large items (cars) ride the existing MAT/PowerPaint racing.
**App:** Distractions group fully enabled (X1–X7): chips mirror person chips, default Keep, Remove all / Keep all, status sentence + confirm label count inclusions (X5), canvas tap priority people > belongings > distractions (X7). S7 summary extension (X16); S6 stage line derives from the job (X15).
**Gate:** per-category would-post test incl. wires-free street scenes, a pole crossing the keeper, the user's-own-car case (false-positive cost); any category failing its bar does not ship.

### Phase C — Shadow v1 (directional growth, no new model)
**Worker:** `mask_prep.py` — estimate dominant light direction per photo from all persons' existing shadow expansions; grow each removed person's mask along that direction within a bounded reachable region; keeper veto (growth stops at protected masks); current below-feet heuristic remains as the floor, not replaced blindly.
**App:** none (X12 — shadows are never items; copy frozen per X13).
**Gate:** blind A/B against the current heuristic on a long-shadow test set (evening side-light, shadows on walls/furniture); ship only if residual-shadow rate drops **and** keeper-shadow damage stays zero.
**STATUS — DONE, GATE PASSED, SHIPPED (2026-10-15).** Investigation: `docs/architecture/phase-c-investigation.md`. Measured: flagship long-shadow mask recall 0.071 → 0.871 (pooled over GT photos 0.147 → 0.224 — v1 deliberately stays silent where cast evidence is weak: faint shadows on bright tile, midday pools, B&W); keeper incursion 0 px on all 7 test photos; blind A/B 1 decisive win + 6 ties, no photo worse on keeper safety; §5 pixel-diff acceptance passes with the new prep. Integrated as `worker/shadow_growth.py` + `mask_prep` `shadow_mode="v1"` (default; `"legacy"` = exact old path), port proven bit-identical to the investigated prototype (0 px diff on 4 photos). Wall shadows UNMEASURED (no sourceable test photo) — no claim made. No app/contract change.

### Phase D — Reflections v1 (detect + warn + guided brush)
**Worker:**
1. License check first (mirror segmentation models/datasets) — no check, no ship.
2. Mirror-region detection (segmentation) + person detections *inside* mirror regions (textbook-mirror case); ghost check learns to not false-alarm on reflected persons.
3. When a removed person has a probable reflection: job meta flags it.
4. **Research spike (timeboxed):** reflective surfaces beyond mirrors — water, shop/car windows, glossy floors. Mirror-region detection does not cover these; the spike evaluates reflective-surface detection as *warn targets only*, plus whether a removed person's reflection inside a detected reflective region can be segmented and fed to the existing inpaint path (the only credible route to automatic removal in this pipeline). Explicit kill criteria: if warn precision on the §5 reflection test set cannot reach the Phase D gate, the surface class is dropped from warnings; automatic removal is claimed only if it passes real-image tests — otherwise it stays a brush case permanently.
**App:** Result gains an honest notice + one-tap path into the Brush with the reflection region pre-suggested as a starting paint (still user-painted, X14); **no promise is made anywhere** (X13). No S4 items.
**Gate:** warn precision/recall measured on a mirror/window/gloss test set; a warn that cries wolf gets its threshold raised or the phase doesn't ship.

### Phase E — GPU-gated (only if/when the owner enables GPU on Modal)
1. Grounding DINO Tiny becomes the default open-vocab detector.
2. **Wires:** train a lightweight wire segmenter (WireSegHR data — terms check first), two-stage global+local segmentation + tile inpainting per Chiu et al.; ships as its own category with its own gate (residual-visibility rating, sky vs complex backgrounds split, OQ7).
3. Shadow v2: learned lightweight shadow detector intersected with the directional region — only after license verification.
4. Reflections remain warn-only (the blocker is a missing model/dataset, not compute).

## 5. Quality programme (applies to every phase)

- **Expansion test set** (built before Phase A ships): staged + real photos per capability — keeper holding a bag; bag between keeper and stranger; ground-placed bag; backpack on a removed person; car/bus/pole/sign/bin street scenes; a pole crossing the keeper; long evening shadows; shadows on walls; mirror, shop-window, water, and glossy-floor reflections; busy-crowd scenes. Stock-photo caveat from the Phase 0 set applies (real phone photos are harder) — include owner-shot photos where possible.
- **Ship gates per phase** (all must hold): **zero protected-set damage** (keeper + their belongings + kept items); removal success at or above the current people-removal bar on the same photos (would-post method from Requirements §3); no regression on the existing 30-photo set.
- **Final-composite pixel-diff acceptance test (added 2026-10-14):** protected-set integrity is proven at the *output*, not assumed from the mask logic — an automated test asserts that the composited image array, outside the union of removal masks, is pixel-identical to the source array before the delivery encode, run over the expansion test set for every phase.
- **Blind A/B** wherever a heuristic is replaced (Phase C) or a threshold is set (Phase B): raters don't know which output is which.
- **Honesty invariants:** no silent fallbacks (a failed detector pass fails the job loudly, per standing rule); fallbacks only behind the existing `PG_ALLOW_FALLBACKS` flag; every estimate in this plan is replaced by a measured number during its phase's spike/calibration step, and the plan doc is updated with the measured values.

## 6. Architecture fit

- **Worker:** all changes land in the existing modules (`detector`, `segmentor`, `mask_prep`, `pipeline`) + one new module (`belongings.py`); engine wiring in `modal_app.py` unchanged; MAT mask-polarity inversion respected in any new mask code.
- **Contract:** v3 is additive over v2 (OQ6); `API_CONTRACT.md` updated in the same commits as the worker changes.
- **Gateway:** no migrations; analyse/confirm/status payloads carry the new fields; the credit model is untouched (one job = one save, X18).
- **App:** changes confined to the Proposal feature (model/controller/view + strings), the Result summary line, and the S6 stage line derivation — the design's guard list (X19) is binding: no new screens, no settings, no strength controls.
- **Design rulings implemented as written:** X1–X19; defaults table in the design doc §8 is the acceptance reference.

## 7. Risks & open items

- Open-vocab CPU cost is **unmeasured** (no published benchmarks) — Phase B's spike can kill or re-scope Phase B; that is its purpose.
- Learned shadow/reflection model **licenses unverified** — Phases C/D are designed to ship without them; v2s wait for checks.
- WireSegHR dataset terms unverified — Phase E only.
- SAM mask cost grows with item count; whether embeddings are cached in the current worker is unverified — checked in Phase A's first step.
- Large-object inpainting (cars) is the weakest fill case in every engine we tested — Phase B's category gate may legitimately withhold "car" even if detection is perfect. Detection quality ≠ removal quality; the gate judges the *result*.
- Crowd-scene inpaint quality remains the product's #1 complaint category overall (per the feature research) — these phases must not be read as outranking core fill quality work.

## 8. Decisions for the owner

1. Approve the phase order **A → B → C → D** (E GPU-gated)?
2. Confirm **wires deferred** to the GPU era (they cannot fit the CPU envelope)?
3. Confirm **reflections = warn + guided brush only**, staying unpromised?
4. Confirm the **Distractions group ships with default-Keep** per design X3 (already ruled by the design lead under its authority — noted here because it shapes Phase B's build)?
