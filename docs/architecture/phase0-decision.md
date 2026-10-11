# Architecture Decision Record: Phase 0 Quality Gate Decision

- **Document:** `docs/architecture/phase0-decision.md`
- **Status:** PENDING REAL RATINGS & DEVELOPER SIGNATURE
- **Date:** 2026-10-12
- **Author / Reviewer:** Sole Developer & Lead Architect
- **Governing Specification:** `PEOPLEGONE_REQUIREMENTS.md` §3 (Mandatory Quality Gate) & §14 (Task 0.4)

---

## 1. Context & Objective

Per `PEOPLEGONE_REQUIREMENTS.md` §3, Phase 0 is the mandatory quality gate that determines whether the chosen pipeline removes background people well enough that blind raters judge the results postable next to free native tools (Google Magic Editor / Apple Clean Up).

Scaffolding the mobile app (Phase 1) is blocked until this decision record documents an objective **GO** outcome.

---

## 2. Test Configuration & Artifact Verification

- **Pipeline Version:** `peoplegone-v1-phase0`
- **Person Detector:** RT-DETR (`PekingU/rtdetr_r50vd`) / DETR (`facebook/detr-resnet-50`) [Apache-2.0, non-AGPL]
- **Instance Segmentor:** SAM 2.1 (`facebook/sam2.1-hiera-tiny`) [Apache-2.0]
- **Inpainting Model:** LaMa (`big-lama` via IOPaint) [Apache-2.0]
- **Fallback / Reference Arm:** Clipdrop Cleanup (`quality` mode)
- **Frozen Test Set Size:** 30 photos across 8 mandated categories
- **Manifest SHA-256 Hash:** `[PENDING: Computed after developer adds photos to testset/photos/]`
- **Rater Panel Size (n):** `[PENDING: 5–10 independent blind raters]`

---

## 3. Decision Rule Thresholds & Measured Metrics (§3.4)

The verdict is determined strictly by the pre-written decision rule in §3.4:

| Metric | Threshold (§3.4) | Measured Result | Status |
| :--- | :--- | :--- | :--- |
| **Overall "Would post" %** | ≥ 70.0% | `[TBD %]` | Pending |
| **Simple-background "Would post" %** | ≥ 90.0% (Photos 1–6) | `[TBD %]` | Pending |
| **Head-to-head win/tie vs native** | ≥ 40.0% | `[TBD %]` | Pending |
| **Keeper-damage critical defects** | **0** (Zero tolerance) | `[TBD count]` | Pending |
| **Median warm end-to-end time** | ≤ 20.0 seconds | `[TBD s]` | Pending |
| **Measured all-in cost / photo** | ≤ $0.0100 | `[TBD $]` | Pending |

---

## 4. Decision Rule Definition

1. **GO:** All 6 criteria meet or exceed thresholds. Proceed immediately to Phase 1 (App Scaffold + mock golden path).
2. **ITERATE:** Change exactly one stage and re-run the same 30 photos:
   - Fills fail, segmentation clean → swap inpaint arm (Clipdrop quality mode / diffusion hard-tile).
   - Segmentation fails, fills good → fix detection (larger SAM 2.1 checkpoint, tuned weights).
   - Shadows dominate complaints → invest in §6.4 shadow handling.
3. **STOP:** Do not build the app if, after one inpaint swap and one segmentation fix: "would post" stays < 50%, or native tools win > 80% of head-to-heads. The project terminates and findings are reported. Polishing an app around a failed core is forbidden.

---

## 5. Formal Verdict

**Verdict:** `[ PENDING EVALUATION: GO / ITERATE / STOP ]`

---

## 6. Developer Sign-off (Human-Only Action)

```
Signed: ___________________________________________
Name:   Israr Kundi
Role:   Sole Developer / Lead Architect
Date:   _____________________
```
