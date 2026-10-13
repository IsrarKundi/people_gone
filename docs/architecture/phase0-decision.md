# Architecture Decision Record: Phase 0 Quality Gate Decision

- **Document:** `docs/architecture/phase0-decision.md`
- **Status:** DECIDED — GO (owner decision, proceeding on current evidence)
- **Date:** 2026-10-13
- **Decided by:** Israr Kundi (owner / sole developer), decision given to the build lead on 2026-10-13
- **Governing Specification:** `PEOPLEGONE_REQUIREMENTS.md` §3 (Mandatory Quality Gate) & §14 (Task 0.4)

---

## 1. Context & Objective

Per `PEOPLEGONE_REQUIREMENTS.md` §3, Phase 0 is the mandatory quality gate that determines whether the chosen pipeline removes background people well enough that blind raters judge the results postable next to the free native tools shipped by Google and Apple.

Scaffolding the mobile app (Phase 1) was blocked until this record documents a decision. **The owner has decided: GO — proceed to Phase 1 on the evidence that exists today, accepting in writing (§5 below) the criteria that were never measured.** This record exists so that nobody later mistakes this for a gate that was run and passed as specified in §3.3/§3.4. It was not. The owner chose to proceed anyway; that choice, its basis, and its gaps are what this document records.

---

## 2. Pipeline as actually tested (differs from the original §3 plan)

- **Person Detector:** RT-DETR (`PekingU/rtdetr_r50vd`) [Apache-2.0]
- **Instance Segmentor:** SAM 2.1 (`facebook/sam2.1-hiera-tiny`) [Apache-2.0]
- **Inpainting — tested arms:**
  - LaMa (`big-lama`) — original primary; smears on large removals.
  - **MAT (`Places_512_FullData`) — selected default fill.** Beat LaMa on texture (grass/blanket), tied on the owner's plaza photo, never invented objects.
  - PowerPaint v1 — best single result (picnic photo) and most believable fill on the owner's photo, but invented two small ground objects there; not adopted as default.
  - SD 1.5 inpainting — rejected: systematically hallucinated objects into person-shaped holes.
- **Test set used:** the 30-photo stock set in `testset/` (Pexels, licence-free) — **not** the §3.2 set of real 12 MP+ phone photos. Stock photos are cleaner than real phone photos, so the test was slightly easier than the spec's.
- **Hosting for the smoke test:** Modal serverless, **CPU container (4 cores / 8 GB)** — not RunPod GPU as §3.1 specified.

---

## 3. Evidence the decision rests on

1. **CPU patch tests (assistant's own visual judgement, not blind raters):**
   - LaMa arm, first 9 photos of the stock set: **6/9 "would post" by the assistant's eye.** Passes were small/distant people on simple ground; all 3 failures were large removals (blur smears) — LaMa's known large-hole limit.
   - MAT arm: clear win over LaMa on the picnic photo (06); tie with LaMa on the owner's photo; failed the couple photo (02) differently (small melted artifacts vs LaMa's blur column). Never invented objects.
   - PowerPaint arm: best result on photo 06; most believable background on the owner's photo but invented two small bag/disc-like ground objects; photo 02 second patch **never completed** (repeated run kills; the owner stopped it).
   - Keeper protection was repeatedly verified: the keeper's pixels are never touched by the composite (architectural property, observed on every run, including the control photo 03 where nothing was removed and the output was untouched).
2. **Hosted end-to-end smoke test — PASSED (2026-10-13, Modal CPU worker):**
   - Input: the owner's own photo (Badshahi Mosque plaza, dusk, 900×1600 chat copy).
   - Result: 13 people detected, keeper = the owner (correct), 12 removed, MAT engine, `fallbacks_used` empty (no fake fills), output at full input resolution.
   - Total time **120 s** on the CPU container (inpaint 51 s + ghost-check 55 s). This is a CPU development figure, not a production timing.

---

## 4. What was NOT measured — stated plainly

Against the §3.4 decision rule, the following are **NOT MEASURED**. No number in this record should be read as satisfying them:

| §3.4 criterion | Threshold | Status |
| :--- | :--- | :--- |
| "Would post" %, overall | ≥ 70% | NOT MEASURED — no blind test, no independent raters; only the assistant's visual calls on partial runs (LaMa 6/9 of the first 9 photos; engine patch tests on 3 photos + the owner's photo). |
| "Would post" %, simple backgrounds | ≥ 90% | NOT MEASURED as a blind metric (simple-background photos were the strongest category in the exploratory runs, but no rater panel scored them). |
| Win/tie vs native tools | ≥ 40% | NOT MEASURED — Google/Apple native outputs were never produced (no Pixel/iPhone available). |
| Keeper-damage critical defects | 0 | Partially evidenced — zero keeper damage observed across all exploratory runs, and the composite architecture cannot touch keeper pixels; but not verified by blind raters on the frozen set. |
| Median warm end-to-end time | ≤ 20 s | NOT MEASURED on GPU. CPU dev worker measured 120 s on the owner's photo; the owner has accepted ~2 min/photo for the development phase (see §5). |
| All-in cost per photo | ≤ $0.01 | NOT MEASURED on GPU. Dev phase runs on Modal's free monthly credits (CPU), so dev cost is $0 out of pocket; production cost per photo on GPU remains an estimate only. |

Also not done, for the record: the frozen 30-photo set was never run end-to-end by any single engine (the LaMa run was stopped by the owner at 9/30; later engines ran patch tests only); the Clipdrop comparison arm was never run; reflections behaviour is untested (v1 does not promise reflections — brush mode + warning only).

---

## 5. Owner decisions recorded with this GO

1. **Proceed on current evidence.** The exploratory evidence above is sufficient for the owner to authorise Phase 1 (app scaffold + mock golden path) and continued engine work. The formal §3.3 blind gate may still be run later; if it is, its result supersedes the assumptions here.
2. **Development processing stays on the CPU Modal worker** at ~2 min/photo. GPU hosting (Modal T4) is deferred by the owner — no payment method will be added for now. Consequence, accepted: dev-phase timings are not production timings, and the ≤20 s / ≤$0.01 criteria stay NOT MEASURED until a GPU run happens.
3. **Application ID / bundle ID:** `mobile.peoplegone.app` (owner decision, 2026-10-13) — to be applied in Phase 1 Task 1.1.
4. **Candidate engine stack:** RT-DETR + SAM 2.1 detection/masks (unchanged); MAT as default fill; LaMa as selectable fallback; PowerPaint racing on large patches remains a planned later stage, not part of this GO.

## 6. Known conflicts with the requirements (owner decision wins; recorded, not hidden)

- §3.4 says GO requires all six criteria measured and met; §14 Task 0.4 says apply the rule "as written". This GO does not satisfy that letter — it is an owner override on partial evidence, recorded here per the owner's instruction. The STOP rule was not triggered by any evidence seen (no engine collapsed; the core job demonstrably works on simple and medium scenes).
- §3.1/§6.4 name RunPod Serverless as the worker host; the dev worker runs on Modal instead (owner's hosting decision, 2026-10-12/13). The worker code stays host-agnostic.
- Requirements name LaMa as the Phase 0 primary inpainting arm; the tested evidence moved the default to MAT (see §2).

## 7. Formal Verdict

**Verdict: GO** — proceed to Phase 1 on current evidence, under the owner decisions in §5 and with the NOT MEASURED items in §4 carried as open risks.

**Biggest open risk, in one line:** quality on large/overlapping removals is not yet at consumer grade in any tested engine, and no blind rater has ever scored this pipeline — the app must be built so a failed result is recoverable (proposal screen, free retries, brush mode), and launch marketing must only claim the proven zone until the formal gate or GPU re-test says otherwise.

---

## 8. Sign-off

```
Decision: GO (proceed on current evidence)
By:       Israr Kundi — owner / sole developer
Date:     2026-10-13
Channel:  Owner instruction to the build lead in chat, 2026-10-13
          ("proceed on current evidence, go with 2 minutes/photo,
          applicationId mobile.peoplegone.app")
```
