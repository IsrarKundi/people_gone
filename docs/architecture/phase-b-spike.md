# Phase B Spike — OmDet-Turbo Tiny Benchmark (measurement only)

**Date:** 2026-10-14 · **Status:** COMPLETE — verdict in §6
**Scope:** Measurement only. No production code changed; the production
`peoplegone-worker` Modal app was not touched. All measurements were taken on a
throwaway Modal app named **`peoplegone-spike`**, configured identically to
production (**cpu=4.0, memory=8192**). The spike app is created on demand by
`modal run`, stops itself when the run ends, and holds no idle resources — it
costs nothing while not running. Spike code, photos, raw results and overlays
live in `~/workspace/peoplegone/phase-b-spike/` (not committed).

**Question (plan §4, OQ1/OQ8):** can OmDet-Turbo Tiny supply the COCO-missing
distraction categories (bin, pole, sign, stroller) inside the existing CPU
container class and job-time envelope? The research estimate under test was
**+4–12 s/photo on CPU — explicitly unmeasured**. This spike replaces it with
measured numbers.

---

## 1. Licence verification

- Upstream repo: https://github.com/om-ai-lab/OmDet — LICENSE file present;
  GitHub repo metadata states **Apache License 2.0 (Apache-2.0)**.
- Model card: https://huggingface.co/omlab/omdet-turbo-swin-tiny-hf — card
  metadata `license: apache-2.0`, `pipeline_tag: zero-shot-object-detection`.
- The checkpoint used is `omlab/omdet-turbo-swin-tiny-hf` (Swin-Tiny variant,
  115,406,806 parameters — counted in-container during the spike).
- Inference runs through stock Hugging Face Transformers
  (`OmDetTurboForObjectDetection`, integrated since transformers 4.45.0). No
  vendor repo code, no custom conversion.

**Licence: Apache-2.0 — VERIFIED from the model's own repo and card.** Safe to
ship commercially on the same basis as RT-DETR / SAM 2.1.

## 2. The numbers — MEASURED ON MODAL cpu=4.0 / 8 GB

Container facts: torch thread count 4 (matches the 4.0 CPU allocation);
weights baked into the image (cold load measures model load, not downloads);
the processor resizes every photo internally to **640×640** regardless of
native resolution (verified from the input tensor shape), so per-photo time is
nearly independent of photo size.

### 2.1 Cold load (fresh container)

| Component | Run A | Run B |
|---|---|---|
| Processor load | 0.77 s | 1.46 s |
| Model load | 1.95 s | 1.68 s |
| **Total model-side cold load** | **2.72 s** | **3.14 s** |

A third measurement inside the combined-stack run timed processor+model
together at 2.25 s (and 3.70 s on its first run). **Cold load ≈ 2–4 s per fresh
container**, paid once per container lifetime, not per photo. For scale: a
completely cold container answering the full 11-photo bench took 42–46 s
client-side end to end (provisioning + loads + 11 inferences + overlay
returns).

### 2.2 Warm inference per photo (native resolution)

Prompt set for every photo: `["trash bin", "pole", "street sign", "stroller",
"car"]`, score threshold 0.25, NMS 0.3. Times are the full per-photo wall time
(preprocess + forward + postprocess) inside the container.

| Photo | Resolution | Run A total | Run B total |
|---|---|---|---|
| 12_market_street.jpg | 6720×4480 (30.1 MP) | 2.59 s * | 1.65 s * |
| 13_metro_entrance.jpg | 4603×3452 (15.9 MP) | 1.69 s | 1.16 s |
| 21_sunny_promenade.jpg | 6016×4000 (24.1 MP) | 1.71 s | 1.22 s |
| 22_sunset_sidewalk.jpg | 4413×5516 (24.3 MP) | 1.74 s | 1.21 s |
| 27_cafe_foreground.jpg | 6000×4000 (24.0 MP) | 1.72 s | 1.26 s |
| 23_street_lamp_shadow.jpg | 3000×2000 (6.0 MP) | 1.50 s | 1.15 s |
| 10_tiled_piazza.jpg | 4423×6635 (29.3 MP) | 1.76 s | 1.23 s |
| 04_desert_dune.jpg | 5472×3648 (20.0 MP) | 1.93 s | 1.18 s |
| px_parked_cars.jpg | 6000×4000 (24.0 MP) | 1.86 s | 1.21 s |
| px_street_cars.jpg | 5184×3456 (17.9 MP) | 1.88 s | 1.20 s |
| px_stroller.jpg | 4873×3249 (15.8 MP) | 1.63 s | 1.17 s |

\* First photo in each run — includes first-forward warmup.

**Warm per-photo cost: ≈ 1.2–1.9 s** (Run A median 1.73 s, Run B median
1.20 s; forward pass alone 1.44–1.62 s in Run A). The research estimate of
+4–12 s was **pessimistic by roughly 3–6×**.

### 2.3 Peak memory

Peak RSS of the Python process (`ru_maxrss`), measured inside the container:

| Configuration | Peak RSS |
|---|---|
| OmDet alone (load + 11 photos) | **4,469–4,476 MB** |
| Base process (torch + transformers imported, no models) | 3,241 MB |
| + OmDet loaded and run | 4,305 MB |
| + production RT-DETR loaded and run (×3 photos) | 4,662 MB |
| + production SAM 2.1 loaded, `set_image` on the 30 MP photo | 5,399 MB |
| + production MAT loaded, inpaint of a 1024×1024 crop | **6,580 MB** |

The combined run loads the **whole production-equivalent stack in one
process** — OmDet-Turbo, RT-DETR (`PekingU/rtdetr_r50vd`), SAM 2.1
(`facebook/sam2.1-hiera-tiny`, loaded the production way), and MAT (production
checkpoint and production `mat_inpainter.py`, pinned MAT repo commit
`d273d89`) — and peaks at **6,580 MB of the 8,192 MB limit: it fits, with
≈ 1.6 GB headroom**. OmDet's marginal resident footprint over the shared torch
base is ≈ 0.75 GB.

Caveats (stated, not hidden): the spike exercised MAT on one 1024×1024 crop —
production inpaints per-person crops sequentially at up to native resolution,
and larger crops use more activation memory; LaMa was not additionally loaded
in the spike process. The Phase B build should re-run this combined-peak check
against a full multi-person `/process` before launch (see §6, constraint 5).

### 2.4 Control category: OmDet "car" vs production RT-DETR "car"

Same three photos, RT-DETR at its production threshold (0.35), warm:

| Photo | RT-DETR cars | RT-DETR time | OmDet cars | OmDet time |
|---|---|---|---|---|
| px_parked_cars.jpg (GT 25+) | 16 | 0.80 s | 11 | 1.2–1.9 s |
| px_street_cars.jpg (GT ~13) | 12 | 0.74 s | 10 | 1.2–1.9 s |
| 23_street_lamp_shadow.jpg (GT 3) | 4 | 0.75 s | 3 + 1 duplicate | 1.2–1.9 s |

**RT-DETR is faster and finds more cars.** OmDet adds nothing for classes COCO
already has; its only possible role is the COCO-missing categories.

## 3. Spot-check quality — MEASURED, judged by eye against ground truth

11 photos; ground truth counted by eye before the run (recorded in the spike
folder). Overlays for every photo are in the spike folder and were inspected.
Detections at score threshold 0.25:

| Category | Ground truth | True hits | False positives | Read |
|---|---|---|---|---|
| car (control) | ~41 | ~24 | 1 duplicate box | ~58% recall — small/distant cars vanish at 640×640 input |
| trash bin | 2 | **2** | **8** | Both real bins found (0.69, 0.39). FPs: boxes over a standing man (0.51), fences (0.44, 0.39), a stone plinth (0.29), a shelter door (0.29), railings (0.26), a person's legs (0.26), a snow-covered mailbox (0.27) |
| pole | ~17 | **0** | 0 | **Total miss.** Utility poles, lamp posts and flagpoles in 5 different photos — none detected at any score ≥ 0.25 |
| street sign | ~27 | 5 | 0 | Only large signs: the metro "Platform 2" sign, the café's main sign + one small sign, one crossing-sign assembly, one marginal distant blurred sign. Every traffic sign in the market street, all pier signage, all neon signs, both no-entry signs — missed |
| stroller | 1 | **1** (0.82) | 1 (a motorcycle, 0.26) | The one real stroller found cleanly and confidently |

Per-photo notes that matter:

- **04_desert_dune.jpg — the negative control (zero targets): 0 detections.
  Clean.** No false positives where nothing exists.
- **10_tiled_piazza.jpg — urban zero-target control: 2 detections** — 1
  marginal hit on a distant blurred sign, 1 false positive ("trash bin" over a
  walking person's legs).
- **12_market_street.jpg — the busy street: 0 detections at all**, against
  ~6 poles and ~4 signs of ground truth. The single worst result in the set.
- **px_stroller.jpg:** the stroller itself is a textbook hit; the same photo
  also produced 4 of the 8 bin false positives.

Why poles and signs fail is visible in the method: the model only ever sees a
640×640 squash of the photo. A lamp post becomes a 2–3 px line; a traffic sign
becomes a ~10 px blob. This is a property of the model's default input path,
not of the photos.

Threshold note (measured trade-off, for calibration): the two true bins scored
0.69 and 0.39; false-positive bins scored 0.26–0.51. A bin threshold of 0.35
keeps both true bins and kills 6 of 8 FPs; 0.55 keeps one true bin and kills
all FPs. There is no threshold at which bins are both complete and clean —
per-category calibration plus the S4 confirm gate (distractions default KEEP,
design X3/X7) is what makes the surviving FPs a glance-cost rather than a
damage risk.

## 4. Envelope math

Baseline job (production, measured): **~120 s** end to end on this container
class.

- **Typical job:** +1.2–1.9 s for one OmDet pass at `/detect` time →
  ~121–122 s, i.e. **+1.0–1.6%**.
- **p95-style worst case:** fresh container (+2–4 s load) and first-photo
  warmup (+2.6 s inference) both landing on the same job → +≈6.6 s ≈ **+5.5%**.
- **The plan's rule (OQ8):** if measured p95 job time grows **>20%** (+24 s),
  the S6 expectation copy must be re-derived before launch. **The spike does
  not trip it** — the margin is roughly 4×. The "~2 minutes" expectation copy
  stands on OmDet's account. (Inpainting time for user-included distraction
  items is separate, per-item work that only happens for items the user
  confirmed; it is not part of this detector measurement.)
- **Modal cost:** containers bill on runtime; +~1.5 s on a ~120 s job is
  ≈ **+1.3% worker compute per photo** — inside the $0.006–0.01/photo budget
  envelope and, at dev scale, negligible against the $30/month free credit.

## 5. What was actually done (honesty log)

- OmDet-Turbo ran **first try** through the stock Transformers path once its
  dependencies were present. Two spike-image build fixes were needed, both
  already satisfied by the production image: `git` (to install SAM 2), `timm`
  (OmDet's Swin backbone loads through it), `click` (MAT's loader imports it).
- **Integration constraint found:** production pins `transformers==4.44.2`,
  which predates OmDet-Turbo support (added in **4.45.0**). The spike used
  **4.46.3**. Adopting OmDet therefore requires a transformers bump in the
  production image, with an RT-DETR/SAM regression pass.
- One full-bench attempt stalled inside its first container with no progress
  for ~12 minutes and was killed; a staged smoke test (load + one photo:
  processor 1.5 s, model 2.2 s, forward 1.4 s) and two subsequent full runs
  completed normally. Cause not identified; most consistent with a wedged
  first container on the new image. Reported here rather than silently
  re-run.
- **Local-VM cross-check: not run, deliberately.** This VM has ~1.1 GB free
  RAM against a measured 4.5 GB OmDet process peak — it would not fit — and
  its Python env pins transformers 4.44.2 (no OmDet support). The Modal
  numbers above are the primary evidence, as specified.
- Grounding DINO Tiny fallback: **not needed** — OmDet ran. It was not
  measured.

## 6. VERDICT — FITS WITH CONSTRAINTS

**On resources, OmDet-Turbo Tiny fits outright**: +1.2–1.9 s/photo warm
(research estimate was +4–12 s), ≈ 2–4 s cold load per container, and the
full production stack plus OmDet peaks at 6,580 MB of 8,192 MB. The 20%
job-time rule is not tripped.

**On quality, it fits only for part of the Phase B category set.** The
constraints for the Phase B build:

1. **Ship stroller** — calibrates cleanly (1/1 found at 0.82, one stray
   low-score FP on a motorcycle).
2. **Ship bins only with per-category threshold calibration** (start at
   ≥ 0.35 from the measured trade-off curve) **and** the existing S4 confirm
   gate with default KEEP. At the naive 0.25 threshold, bin precision in this
   set was 2/10 — not shippable as-is, acceptable as calibrated suggestions
   the user confirms.
3. **Withhold pole entirely** — 0/~17 measured. Do not list it, do not merge
   it into "Other" (plan OQ1 allows withholding; a category that finds
   nothing teaches users the feature is broken). Re-test only if a fix is
   measured first — the candidate fix is tiled inference (overlapping
   native-scale tiles instead of one 640×640 squash; each tile ≈ one more
   ~1.3 s forward, so a 2×2 pass ≈ +5–7 s/photo — inside the envelope, but
   its quality effect is UNMEASURED).
4. **Withhold sign, or ship as large-signs-only with calibrated
   expectations** — 5/~27 recall, all large signs; traffic signs (the case
   users most mean by "sign") were missed everywhere. Same tiling re-test
   path as poles.
5. **Integration constraints for the build:** (a) bump transformers
   4.44.2 → ≥ 4.45 with an RT-DETR/SAM regression pass; (b) run OmDet once
   per job at `/detect` time only (feeds Contract v3 `items[]`), never per
   crop and not inside `/process`; (c) cars and all other COCO classes stay
   on RT-DETR (measured faster, higher recall); (d) re-run the
   combined-peak memory check against a full multi-person `/process` (large
   MAT crops, LaMa loaded) before launch — measured headroom is ≈ 1.6 GB on
   a representative flow, not on the worst-case job.

If constraints 3–4 are unacceptable — i.e. if Phase B must launch with poles
and traffic signs working — then OmDet-Turbo Tiny as measured **does not
fit**, and what would have to change is one of: a measured tiling pass on
this model, a different open-vocab model (Grounding DINO Tiny, unmeasured),
or the GPU era (Phase E), where higher input resolutions become affordable.

---

*Raw evidence: `~/workspace/peoplegone/phase-b-spike/` — `results/omdet_results.json`,
`results/combined_results.json`, `results/ground_truth.md`, `overlays/` (11
annotated photos), `spike_app.py`, `smoke_app.py`, run logs.*
