# Phase B — Distractions calibration (the gate inside the build)

Status: **DETECTION GATE MEASURED 2026-10-14** · Removal-quality gate runs
against the built worker (evidence cited at the end; categories that fail
removal are dropped from the shipped config before app wiring is final).

Owner scope (2026-10-14): build with the passing categories only. **Poles
and street signs are withheld entirely** (Phase B spike: OmDet found 0 of
~17 poles and only large signs). Candidates measured here:

- RT-DETR COCO pass: car, bus, truck, motorbike, bicycle, traffic light,
  stop sign, parking meter, bench, fire hydrant.
- OmDet-Turbo prompts: "trash bin", "stroller" ONLY.

**Label note:** this RT-DETR checkpoint (`PekingU/rtdetr_r50vd`) emits
`motorbike`, not the canonical COCO `motorcycle`. The shipped config uses
the checkpoint's own label.

## Method

- Test set: **30 photos** — the spike's 11, 2 testset-pack street scenes
  (festival crowd = negative control, night bazaar = scooters), 17 Pexels
  street/café photos chosen to cover the classes the spike set lacked
  (bus, truck, bicycle rows, traffic lights, stop signs, parking meters ×3,
  fire hydrants ×3, benches, a second stroller, bins).
- Both detectors run on a production-class Modal CPU container
  (cpu=4.0 / 8GB, transformers 4.46.3): RT-DETR all classes and OmDet
  (prompts above, NMS 0.3) captured at score ≥ 0.10.
- **321 candidate detections ≥ 0.25 were judged one by one by eye**
  (numbered crop montages; verdict per detection: TP = the box covers a
  real instance of its class, FP otherwise; duplicates of a real object
  count TP and are handled by dedupe). Working files (photos, raw JSON,
  verdict ledger, analysis script) live outside the repo in
  `~/workspace/peoplegone/phase-b-build/`.
- Precision is reported RAW (detector output at a threshold) and
  PRODUCTION-SIMULATED: per-category thresholds + geometric dedupe
  (IoU ≥ 0.5 or containment ≥ 0.7 of the smaller box, highest score wins,
  across all RT-DETR classes) + OmDet suppression. The shipped suppression
  is **mask-level**: an OmDet item whose SAM mask is ≥ 60% inside the
  union of person + belonging + RT-DETR item masks is dropped (it is the
  same physical object the closed-vocab detector already named). The
  simulation approximates it with near-identity boxes (IoU ≥ 0.5, or
  containment ≥ 0.9 with area ratio ≤ 3) — the approximation and the mask
  rule agree on every case in this set, and the mask rule is strictly
  safer for occlusion (a bin standing in front of a truck survives: the
  masks are disjoint even though the boxes overlap 96%).

## Raw precision (TP/FP by threshold)

| category | @0.25 | @0.35 | @0.45 | @0.55 | @0.65 |
|---|---|---|---|---|---|
| car | 79/4 | 55/2 | **42/0** | 34/0 | 27/0 |
| bus | 7/0 | 5/0 | **4/0** | 3/0 | 2/0 |
| truck | 3/6 | 2/1 | 2/0 | **2/0** | 2/0 |
| motorbike | 8/2 | 5/1 | 5/1 | **5/0** | 4/0 |
| bicycle | 76/0 | 28/0 | **16/0** | 10/0 | 5/0 |
| traffic light | 20/11 | 18/3 | 14/2 | 12/2 | **9/0** |
| stop sign | 2/4 | 2/2 | 2/0 | 2/0 | 2/0 |
| parking meter | 4/5 | 4/2 | 4/0 | **4/0** | 4/0 |
| bench | 15/3 | 9/0 | **8/0** | 5/0 | 4/0 |
| fire hydrant | 3/1 | 3/1 | 3/1 | **3/0** | 3/0 |
| trash bin (OmDet) | 5/56 | 5/21 | 5/11 | 3/7 | 3/3 |
| stroller (OmDet) | 2/5 | 2/0 | **2/0** | 2/0 | 2/0 |

Failure families worth naming:

- **Traffic light < 0.65**: dusk street lamps (0.59–0.64), a dark window
  (0.40), no-entry signs (0.28–0.34). Clean at 0.65 (9 TP, 3 photos).
- **Stop sign**: the only TPs in 30 photos are two shots of the SAME
  Varna sign pole (0.95). Everything else circular was misread as a stop
  sign: no-entry ×2 (0.39, 0.40), no-parking (0.31), a shop logo (0.27).
- **Truck < 0.55**: white cars/vans in a parked row (0.27–0.35, box twins
  of car detections — cross-class dedupe removes them anyway).
- **Motorbike < 0.55**: a black CAR at 0.53 (night bazaar), a food cart
  at 0.28.
- **Parking meter < 0.45**: a bicycle BELL at 0.41, blur slivers ≤ 0.45.
- **Fire hydrant < 0.55**: a white bollard at 0.45.
- **Trash bin (OmDet)**: raw precision is poor at every threshold — the
  prompt fires on fences, stalls, legs, hedges (0.58), crossing-button
  boxes (0.51), bollards (0.52). BUT at ≥ 0.65 the only FPs left are
  three parking meters (0.70 ×3) — exactly the family the mask-level
  suppression removes (near-identical box/mask to the RT-DETR meter).
  True bins found ≥ 0.65: blue wheelie bin 0.85, black sidewalk bin 0.85,
  pier bin 0.77. (Two more true bins at 0.53 are sacrificed — X6: items
  under the bar are not shown.)
- **Stroller (OmDet)**: 2/2 found (0.79, 0.71); all FPs ≤ 0.34 are other
  vehicles/bike rows, removed by dedupe/suppression or threshold.

## Ship decisions (detection gate)

Detection-calibrated registry — measured **83 TP / 0 FP (100%)** in
the production simulation at these per-category thresholds. (This
table is the DETECTION gate's outcome. Whether any of these actually
SHIPS is decided by the removal-quality gate at the bottom of this
doc — read that before treating this table as a feature list.)

| category | source | threshold | sim items |
|---|---|---|---|
| car | RT-DETR | 0.45 | 39 |
| bus | RT-DETR | 0.45 | 3 |
| truck | RT-DETR | 0.55 | 2 |
| motorbike | RT-DETR | 0.55 | 4 |
| bicycle | RT-DETR | 0.45 | 7 |
| traffic light | RT-DETR | 0.65 | 9 |
| parking meter | RT-DETR | 0.55 | 4 |
| bench | RT-DETR | 0.45 | 7 |
| fire hydrant | RT-DETR | 0.55 | 3 |
| trash bin | OmDet | 0.65 | 3 |
| stroller | OmDet | 0.45 | 2 |

**WITHHELD: stop sign.** The ≥ 95% bar is technically met at ≥ 0.45
(2 TP / 0 FP) but the evidence is one physical sign photographed twice
at close range, against a systematic confusion family (every other
circular sign in the set was called a stop sign). No TP exists at a
realistic distance. Shipping on this evidence would be dressing a guess
up as a measurement — the category stays out until a test set with
several real stop signs at street distance says otherwise. It can be
re-enabled by adding one config line; nothing else changes.

Thin-evidence disclosures (detection gate, stated plainly): truck TPs = 2
physical trucks; bus = 3 items / 2 physical buses (one articulated bus
counts as 2 items — front + rear units); parking meter = 4 detections /
3 physical meters across 3 photos; stroller = 2 physical strollers;
fire hydrant = 3 physical hydrants across 3 photos. Bicycle boxes in
dense rows are often PARTS (wheel clusters) rather than whole bikes —
precision is unaffected (the pixels are bicycle), item granularity is
coarse, and the removal gate below is where that is judged.

## Removal-quality gate

Rule (owner): detection alone never ships a category — a full clean
removing that category must judge **would-post**. Samples run against
the built worker (MAT, protected-set clipping active), before/afters in
`~/workspace/peoplegone/phase-b-build/evidence/`:

### Results (2026-10-15) — SHIPPED SET: EMPTY

Every category failed this gate on its evidence sample, or produced
no sample at all. Per the owner's ship rule the shipped set is
therefore **empty** (`SHIPPED_DISTRACTION_CATEGORIES = set()` in
`server/worker/distractions.py`): the machinery is built, deployed
and tested end-to-end, `/detect` returns `distractions: []`, and the
S4 group never renders. Enabling a category later is one line — add
its name to the shipped set after a passing removal sample.

How the samples were chosen (stated plainly, because it bounds what
this verdict means): one sample per category, targeting the
highest-scoring detected instance — in practice the LARGEST instance
in the frame. That is the pipeline's known weak case (the same
large-hole MAT fill limit documented for people since Phase 0: small
removals are clean, frame-filling removals smear). A typical-scale
second round was designed but NOT run — the owner capped photo
testing on 2026-10-15 ("dont test too much or alot of street
photos"). These verdicts therefore read: "not proven would-post;
failed at large scale" — not "can never work". The named untested
levers for a future pass are (a) typical-scale samples, and (b)
`engine="auto"` (PowerPaint racing on large crops — PowerPaint was
the best large-area fill in the Phase 0 engine tests; all samples
below ran the MAT default).

| category | sample (evidence file) | verdict |
|---|---|---|
| car | minivan, close range, px_hydrant_street (`car_minivan_ba.jpg`) | FAIL — dark smear across the van's area; ghost check fired + retried, fill still smeared |
| bus | articulated bus, px_bus_intersection (`bus_articulated_ba.jpg`) | FAIL — fill invented a kiosk/poster scene + a blob object on the sidewalk |
| truck | box truck, ~55% of frame, px_truck_white (`truck_street_ba.jpg`) | FAIL — worst sample: mangled glass-like architecture, invented signs |
| motorbike | red scooter, 15_night_bazaar (`motorbike_scooter_ba.jpg`) | FAIL (sample confounded: the job also removed 19 people in a dense night crowd; the clean as a whole is a neon-smear disaster and the scooter area with it) |
| bicycle | front bikes of an interlocked row, px_bicycles_cruisers (`bicycle_row_ba.jpg`) | FAIL — left half melted into smeared wall + distorted wheel arcs (both people in frame were keepers and stayed pixel-clean) |
| traffic light | left unit of a 3-unit stack vs plain sky, px_traffic_stop (`traffic_light_stack_ba.jpg`) | FAIL — closest call: sky fill is clean except a visible translucent GHOST of the removed unit; ghost check fired + retried and the residual remained |
| parking meter | two meters, extreme close-up, px_meters (`parking_meter_ba.jpg`) | FAIL — melted black remnant with a white ring left standing in the road |
| bench | mid-distance bench, px_benches (`bench_row_ba.jpg`) | FAIL (sample confounded: the removed bench had a sitting person who was also removed; the combined hole filled as a whitish smear on the promenade) |
| fire hydrant | hydrant, ~45% of frame height, px_hydrant_red (`hydrant_red_ba.jpg`) | FAIL — dark fragments of the hydrant left floating over the road + a hole-like patch on the bricks; ghost check fired + retried |
| trash bin | px_bin_truck (`bin_wheelie`) | NO SAMPLE — production `/detect` returned NO bin on this photo (only the truck). Calibration had measured the bin TP at 0.853, but with a 5-prompt OmDet set; production ships a 2-prompt set ("trash bin", "stroller") and scores/suppression differ. No removal evidence exists → cannot ship |
| stroller | stroller between its two parents, spike photo (`stroller_parents_ba.jpg`) | FAIL — both parents kept and pixel-clean (protected-set clipping worked exactly as designed), but the stroller's place is a melted grey-blue smear with an invented white blob at the father's hand |

What DID pass, for the record: the §5 final-composite pixel-diff
acceptance (belongs + distraction cases, real models) — an included
distraction's mask contained ZERO keeper pixels and the composite was
pixel-identical outside the removal union. Protected-set clipping is
proven; it is the FILL that fails at these scales, not the safety
machinery.
