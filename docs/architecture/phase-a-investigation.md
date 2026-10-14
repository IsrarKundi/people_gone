# Phase A Investigation — Belongings Association: Prototype + Measurement

**Date:** 2026-10-14
**Status:** INVESTIGATION ONLY — no product code was changed. Prototype and working files live in `~/workspace/peoplegone/phase-a-investigation/` (not committed; this report is the only repo artefact).
**Parent plan:** `docs/architecture/removal-expansion-plan.md` §4 Phase A, with the association rule as amended 2026-10-14 (auto-attach requires contiguity with **exactly one** person's halo; touching two people = ambiguous by construction; proximity alone never attaches).
**Design rulings exercised:** X8–X11 (belongings follow their person; ambiguous items become user-decided chips, default Keep; the keeper's belongings are protected).

---

## 1. Question under test

When a person is removed, their carried items (backpack, handbag, suitcase, umbrella) are left floating by the current pipeline unless the person's mask happens to cover them. Phase A proposes: detect the belongings classes the existing RT-DETR checkpoint already returns, segment them with SAM, and attach each item to a person by mask geometry. This investigation measures whether that geometry is trustworthy enough to build on — above all, whether it ever attaches a **keeper's** belonging to a **removed** person (the hard gate: must be zero).

## 2. Method (reproducible from this report)

Prototype: `phase-a-investigation/proto_detect.py` + `score.py`, run with the Phase 0 venv (`phase0-run/venv`, torch 2.5.1, transformers 4.44.2) on a 2-core CPU machine, models fully offline from the existing HF cache.

1. **Detect** — RT-DETR `PekingU/rtdetr_r50vd` via transformers, exactly the worker's `detector.py` code path and its production threshold **0.35**. One difference, the thing under investigation: instead of discarding every non-person label, detections whose COCO label is in {backpack, handbag, suitcase, umbrella, bicycle} are kept as belongings. (Umbrella and bicycle were sought; zero instances occurred in this set.) Raw detections ≥ 0.25 were also dumped for sensitivity notes. Persons get the worker's size filter (w > 10, h > 20).
2. **Segment** — SAM 2.1 `facebook/sam2.1-hiera-tiny`, the worker's `segmentor.py` pattern: **one** `set_image()` per photo, then one `predict(box)` per box, persons and belongings in the same call, `multimask_output=False`.
3. **Halo** — per person: `fill_mask_holes(person mask)` dilated by `max(8, int(0.02 × person box height))` px with the ellipse kernel — the exact formula and kernel in the worker's `mask_prep.py` (this is the same dilated mask the pipeline already inpaints from).
4. **Tier decision** — a belonging's SAM mask is tested against every halo (pixel overlap > 0 = touch):
   - **strict** (the plan's rule, literally): attached(P) iff exactly one halo is touched; 0 or ≥ 2 touches → ambiguous.
   - **de-minimis** (variant measured alongside): a touch counts only if its overlap ≥ max(100 px, 5% of the item's largest halo overlap) — boundary-graze contacts are ignored; then the same exactly-one rule.
5. **Ground truth** — annotated by eye from numbered detection overlays + the originals (and one zoomed crop). Each photo designates keeper person(s); everyone else is "removed". Each physical belonging gets a GT owner (or "contestable") and an expected tier. Ambiguous counts as **correct** when GT ownership is genuinely contestable, and as a **safe miss** when GT ownership is clear (the product shows it as a user-decided chip, default Keep — safe, but manual).

## 3. Test set (11 photos, 16 ground-truth belongings)

| Photo | Source | Cases covered | GT belongings |
|---|---|---|---|
| `owner_mosque.jpg` (900×1600) | Owner's own photo (Badshahi Mosque) | 1 | Messenger bag worn by removed man P4, standing beside keeper P0 |
| `px_two_women_bags.jpg` (3911×4889) | Pexels 9168245 (cottonbro) | **1, 2** | Keeper P1's green handbag held between the two women (critical case 2); removed P0's handbag |
| `px_store_handbag_man.jpg` (5760×3840) | Pexels 8201180 (Kampus) | 2 | Keeper P1 holding a handbag up in a shop, removed P0 beside her |
| `px_bench_couple.jpg` (4749×3166) | Pexels 5225125 (Samson Katt) | 4 | Removed P1's backpack, worn on one shoulder, seated beside keeper P0 |
| `px_luggage_street.jpg` (1664×2496) | Pexels 9140692 (Jim Burnett) | **5**, 4 | Rolling suitcase standing on the ground, held by its handle (case 5); her worn backpack (front view) |
| `24_mountain_trail.jpg` (6000×4000) | Testset pack #24 (Pexels) | 4 | Keeper's yellow backpack (control); distant pair's backpack |
| `10_tiled_piazza.jpg` (4423×6635) | Testset pack #10 (Pexels) | 1 | Tote slung on keeper P0's shoulder; P0/P1 hold hands |
| `12_market_street.jpg` (6720×4480) | Testset pack #12 (Pexels) | 1 (crowd stress) | Held shopping bag; boy's backpack; one low-confidence item. No keeper designated — everyone treated as removed |
| `27_cafe_foreground.jpg` (6000×4000) | Testset pack #27 (Pexels) | 3-form (crowd stress) | Standing woman's bag; one genuinely contestable bag; one frame-edge bag. No keeper designated |
| `owner_cafe.jpg` (639×360) | Owner's photo (café demo) | control | No belongings present; none detected (no false positives) |
| `06_park_lawn.jpg` (5238×3492) | Testset pack #06 (Pexels) | control | No belongings present; none detected (no false positives) |

Case coverage against the owner's five named cases: **(1)** removed person holding a bag — mosque, two-women B1, market B0 ✓ · **(2)** kept person holding a bag close to a removed person — two-women B0, store B0 ✓ (the critical geometry) · **(3)** bag between two people — covered in held-between form (two-women B0 hangs between the women; café B1 is genuinely between two people); a staged "bag sitting on the ground between two people" photo could **not** be sourced from free stock in this pass — reported as a gap, not faked · **(4)** backpack worn by a removed person — bench, mountain pair ✓ · **(5)** object on the ground near a person — luggage-street suitcase ✓.

## 4. Results

### 4.1 Headline metrics

| Metric | Strict rule (plan as written) | With de-minimis contact filter |
|---|---|---|
| Belongings detection recall (GT-countable set) | **16 / 16 = 100%** | same |
| Auto-attached items | 8 | 12 |
| **Auto-attach precision** (attached to the true owner) | **8 / 8 = 100%** | **12 / 12 = 100%** |
| Wrong-owner attachments | 0 | 0 |
| **FALSE attachments — keeper's belonging attached to a removed person (HARD GATE)** | **0** | **0** |
| Ambiguous on clear-ownership items | 5 / 11 = 45% | **1 / 11 = 9%** |
| Ambiguous on contestable items (correct outcome) | 1 / 1 | 1 / 1 |

Detection-recall caveats (honest limits of the 100%): the market-street raw dump (≥ 0.25) contains **7 further belongings-class detections between 0.25–0.35** in the crowd — real bags among them are missed at the production threshold; the piazza has one possible extra item at 0.276 (unverified); the mountain trio's packs are below detection at their size. Recall is 100% on *clearly visible, countable* items; crowded/distant scenes have a sub-threshold tail.

### 4.2 Per-item results (de-minimis variant; strict differs only where noted)

| Photo / item | Detected as (conf) | GT owner | Tier → owner | Verdict | Item mask already inside owner's halo today* |
|---|---|---|---|---|---|
| Mosque — messenger bag | handbag 0.807 | P4 (removed) | attached → P4 (strict: ambiguous) | ✓ correct | 100% |
| Mountain — yellow backpack | backpack 0.839 | P0 (**keeper**) | attached → P0 | ✓ correct | 49% |
| Mountain — distant pack | backpack 0.389 | one of P1/P2 (removed pair) | attached → P1 | ✓ correct (wearer indeterminate within pair) | — |
| Piazza — tote | handbag 0.928 | P0 (**keeper**) | attached → P0 (strict: ambiguous) | ✓ correct | 93% |
| Two women — green bag | handbag 0.935 | P1 (**keeper**) | attached → P1 | ✓ **correct — the critical case 2** | 50% |
| Two women — blue bag | handbag 0.902 | P0 (removed) | attached → P0 (strict: ambiguous) | ✓ correct | 63% |
| Store — held bag | "suitcase" 0.478 | P1 (**keeper**) | attached → P1 | ✓ correct (class label wrong) | 52% |
| Bench — backpack | "handbag" 0.706 (+ "backpack" 0.395) | P1 (removed) | attached → P1 | ✓ correct (double-detected, class split) | 100% |
| Luggage — suitcase on ground | suitcase 0.848 | P0 (only person) | attached → P0 | ✓ correct — **case 5** | **1%** |
| Luggage — worn backpack | backpack 0.389 (+ "handbag" 0.432) | P0 | attached → P0 | ✓ correct (double-detected) | 100% |
| Market — held shopping bag | handbag 0.898 | P2 (removed) | attached → P2 (strict: ambiguous) | ✓ correct | 71% |
| Market — boy's backpack | backpack 0.428 (+ 0.379) | the boy (= P6 **and** P16) | ambiguous | safe miss (owner double-detected) | — |
| Market — bottom-edge item | handbag 0.388 | P3 (probable, low-conf GT) | ambiguous | safe miss | 100% |
| Café — standing woman's bag | handbag 0.722 | P2 | attached → P2 | ✓ correct | 33% |
| Café — contestable bag | handbag 0.562 | contestable | ambiguous | ✓ correct-ambiguous (case-3 form) | — |
| Café — frame-edge bag | handbag 0.428 (+ 0.374) | P12 (probable, low-conf GT) | ambiguous | safe miss | 100% |

\* "Already inside owner's halo today" = the share of the item's mask that lies within its owner's dilated person mask — i.e. the share the **current** pipeline would already remove when the owner is removed. The rest is what floats today. The ground suitcase (1%) is the floating-bag defect at full strength; the two held handbags (50%, 63%) and the store bag (52%) would each leave roughly half a bag behind.

### 4.3 The critical case, in detail (case 2 — two-women photo)

Keeper P1's green bag hangs from her hand *between* the two women, closer in image space to the removed woman's legs than to the keeper's torso. Its SAM mask overlaps the keeper's halo by 92,159 px and the removed woman's halo by **0 px** — the halo follows the body, and the bag hangs against the keeper's own legs. It attaches to the keeper under both rule variants. The removed woman's own bag attaches to her (strict rule: ambiguous, due to a 637 px graze of the keeper's halo — see §5). Visual evidence: `overlays/evidence_px_two_women_bags_B0.jpg` in the working folder (red = item mask, green = owner halo, yellow = rival halo).

## 5. Failure analysis (every miss, from the geometry)

No item was attached to a wrong owner, and no keeper item was attached to a removed person, under either rule variant. All misses are **safe misses** (ambiguous → user decides). Their causes:

1. **Graze contacts break the strict rule (4 clear items).** The mosque bag's mask sits 100% inside its owner's mask, yet a *partial person behind the keeper* (P10) grazes it with **56 px** of halo overlap — under a literal "exactly one halo, any overlap" rule this clear item becomes ambiguous. Same pattern: two-women B1 (637 px graze), market held bag (2,681 px, 2.4% of its main contact), piazza tote (10,374 px, 4.5% — a genuine graze: the couple hold hands, so the other keeper's halo legitimately reaches the tote's edge). All four resolve correctly with the de-minimis filter (a touch counts only at ≥ max(100 px, 5% of the item's largest contact)); precision and the hard gate are unchanged.
2. **Duplicate person detections create fake two-owner geometry (market boy's backpack).** RT-DETR returned the boy twice (P6 and P16, ~90% overlapping boxes). His backpack's SAM mask (~533k px — oversized; the loose box made SAM return pack + torso) overlaps both duplicate halos fully → ambiguous. Root cause is upstream of the tier rule: the worker has no dedupe pass over person boxes. The item also demonstrates SAM mask bleed on loose boxes in crowds.
3. **Dense standing crowds graze items from the side (café frame-edge bag, market bottom-edge item).** The café item's mask is ~100% inside its probable owner's person mask, but a shoulder-to-shoulder neighbour's halo still overlaps it by 13,456 px (12.8% of the main contact — above the 5% de-minimis bar), so it stays ambiguous under both variants. This is the rule working as designed (when in doubt, ask the user), at the cost of manual decisions in crowd shots.
4. **Thin contact on ground items (luggage suitcase — a success, but fragile).** The suitcase attached on a contact of just **1,030 px (0.7% of its mask)** — her halo reaches the handle-side edge she is holding. A suitcase standing a few centimetres further from its owner would touch no halo and land ambiguous. That is the intended safe outcome (X10), but the product should expect a steady share of ground items to arrive as user-decided chips rather than auto-attached.
5. **Detector label noise (3 of 16 primary detections).** A held handbag was labelled "suitcase" (store), a worn backpack "handbag" (bench primary; also the luggage backpack's front part). Association is geometry-based and unaffected — but any UI text naming the item ("Includes: Suitcase") would sometimes state the wrong class. Labels must be treated as a hint, not a fact.
6. **Duplicate belongings detections (4 of 16 items).** The same physical item fired twice with near-identical boxes (bench pack, market boy pack, café edge bag, luggage pack — the last as two different classes over sub-regions). The build needs a dedupe step (mask-IoU merge) before tiering, or the user sees double chips.

## 6. SAM embedding cost — the plan's open question, answered from code + measurement

**Question:** in the worker's `segmentor.py`, are SAM image embeddings cached/reused across boxes — does adding belongings boxes cost a full re-encode or only per-box decode?

**Answer: reused — one encode per photo, pennies per extra box — provided belongings go through the same `segment_boxes()` call.** The code calls `self._predictor.set_image(image_np)` **once** per `segment_boxes()` invocation, then loops `predict(box=…)` per box; SAM2's predictor caches the image features at `set_image` and reuses them for every prompt. Measured on this machine (2-core CPU; absolute numbers will differ on Modal, the ratio is the point):

| Stage | Measured |
|---|---|
| RT-DETR detect (whole photo) | 2.8–5.2 s — **unchanged** by Phase A (same forward pass; the worker currently just filters the extra classes away) |
| SAM `set_image` (the encode) | 6.6–9.3 s, **once** |
| SAM `predict` per box | 0.10–0.49 s each (mosque: 14 boxes = 1.64 s total vs 9.31 s encode) |

So ~4 belongings boxes add roughly **+0.5–1.5 s** per photo (per-box decode only). The trap to avoid in the build: segmenting belongings via a **second** `segment_boxes()` call would pay the full encode a second time (+6.6–9.3 s). Phase A must pass person + belongings boxes in **one** call. (Plan §7's "SAM embedding caching unverified" item is now closed: verified in code and by timing.)

## 7. Gate verdict — **ADJUST the rules, then PROCEED to the Phase A build**

The hard gate passes with margin: **zero false attachments** of a keeper's belonging to a removed person, **zero wrong-owner attachments**, and **100% auto-attach precision** — under the plan's rule as written *and* under the adjusted rule. Detection found every clearly-visible GT item. The geometry (halo = the pipeline's own dilated person mask) is the right primitive: worn and held items sit inside or against their owner's halo because the halo follows the body.

The plan's rule as literally written is, however, too brittle to ship unchanged: **45% of clear-ownership items fall to ambiguous on graze contacts as small as 56 px.** Required adjustments before/within the build:

1. **Adopt the de-minimis contact filter** in the tier rule: a halo touch counts only if overlap ≥ max(100 px, 5% of the item's largest halo overlap). Measured effect on this set: ambiguous-on-clear falls 45% → 9%, precision stays 100%, hard gate stays 0.
2. **Dedupe before tiering:** merge person boxes that duplicate one person (the market boy: two boxes, ~90% overlap) and merge belongings detections whose masks substantially overlap (4/16 items double-fired). Without this, crowds manufacture false ambiguity and double UI chips.
3. **Treat the detected class as a hint, not a label of record** (3/16 primary detections mislabelled: handbag↔suitcase, backpack↔handbag). UI copy that names an attached item should use the class cautiously (or a generic term), per X9's "Includes: …" line.
4. **Expect ground items to split:** handle-held ground items with body contact attach (suitcase ✓, on a thin 1,030 px contact); ground items merely *near* a person will land ambiguous by design — that is X10 working, and the S4 chip flow must be sized for it.

Residual risks the build's own gate must re-measure on a larger set: crowd density (both crowd photos produced the only stubborn safe misses), sub-threshold belongings in crowds (the 0.25–0.35 tail), and the unsourced staged case (a bag on the ground *between* two people) — recommend adding that photo plus more case-2 pairs to the ship-gate set in the Phase A build task (§5 of the plan), where the final-composite pixel-diff test also applies.

**Bottom line:** the association approach is sound and the dangerous failure mode did not occur once in 16 items across 11 photos, including the owner's critical case. Proceed to the Phase A build with the four adjustments above written into it.
