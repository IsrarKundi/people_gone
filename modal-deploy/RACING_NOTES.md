# PowerPaint racing (engine="auto") — verification notes, 2026-10-14

Code: `pp_inpainter.py` (PowerPaint v1, Phase 0 recipe from
`phase0-run/pp_apply.py`: SD-inpainting base fp32 CPU, TokenizerWrapper +
add_tokens with num_vectors_per_token parsed from the official repo's
app.py, PowerPaint-v1 unet/text_encoder safetensors loaded non-strict +
verified, UniPC, removal prompts "empty scene blur  P_ctxt" / negatives
" P_obj", guidance 10, 640px short-side crops, seed 42, PP_STEPS=30) and
`racing_inpainter.py` (race iff mask_ratio >= 0.15 AND mask_area >=
40,000 px; winner = lower ghost-check residual sum at 0.30 confidence;
tie → MAT). Weights/repo are baked into the Modal image
(SD-inpainting snapshot, JunhaoZhuang/PowerPaint-v1 safetensors into
/models/powerpaint/{unet,text_encoder}, open-mmlab/PowerPaint cloned at
pinned commit 5b4c3d52291709fcec2a1870d987da693fd3549c — the same HEAD
as the Phase 0 harness). All code was committed and pushed BEFORE these
verification runs (commit 563950c).

Raw metas (image_base64 stripped) are in `racing_evidence/`:
`piazza_auto.json`, `mosque_auto.json`, `piazza_mat.json`.

## Runs (live, with worker key, CPU container 4 cores / 8 GB)

| run | wall | total_s | persons | keeper | crops | ghost_fired |
|---|---|---|---|---|---|---|
| piazza engine=mat (baseline) | 156.2 s | 141.75 | 15 | [0, 1] | 13 | true |
| piazza engine=auto | 334.3 s | 316.55 | 15 | [0, 1] | 13 | true |
| mosque engine=auto | 111.1 s | 97.95 | 13 | [0] | 12 | true |

### Per-crop racing records
- Mosque (auto): 24 records (12 initial + 12 ghost-retry), **0 raced**.
  Mask ratios ranged 0.002–0.062 — per-person crops include at least
  512 px of context on every side (get_crop_bounds), so the hole is
  always a small fraction of its crop. Auto behaved exactly as MAT.
- Piazza (auto): 26 records (13 initial + 13 ghost-retry), **1 raced** —
  a ghost-retry crop, mask_ratio 0.150258, mask_area 230,374 px:
  - MAT: residual 2.3988, 2,665 ms
  - PowerPaint: residual 2.6830, 219,395 ms (this call includes the
    one-time lazy weight load; Modal logs confirm the pipeline loaded
    and the P_ctxt/P_shape/P_obj tokens were added)
  - **Winner: MAT** (lower residual). All other 25 crops: MAT only.

## Infrastructure finding (fixed during this work)
The first piazza auto attempt failed at 304.8 s with HTTP 500
"modal-http: internal error: function execution timed out": the web
ASGI function had Modal's default 300 s timeout while waiting on the
Processor, whose own timeout was 900 s. Both are now 1800 s
(commit 628579b) and the reruns above completed. No OOM occurred:
PowerPaint loaded and ran a 30-step crop inside the existing
memory=8192 container, so the memory bump was NOT needed.

## Honest verdict
**Racing did not beat MAT-only on the piazza crowd in this run.**
The single crop that met the race threshold picked MAT
(residual 2.40 vs PowerPaint 2.68), and `ghost_check_fired` was true
for BOTH the auto run and the MAT-only baseline — racing changed no
outcome there, while the total time more than doubled
(316.5 s vs 141.7 s), almost entirely the one PowerPaint call
(~219 s including lazy load, inside the ghost-check stage time).
On the mosque photo racing never triggered at all.

Caveats that matter for interpreting this:
- The race threshold (ratio >= 0.15 of the CONTEXT crop) is rarely met
  by construction: crops carry >=512 px context, so even a 391,027 px
  hole scored ratio 0.144 and did not race. If racing is meant to fire
  on the large-removal cases where MAT smears, the ratio would need to
  be measured against the mask bbox, not the context crop — that is a
  design decision, not changed here (implemented exactly as specified).
- The residual score counts every person detection inside the crop
  bounds, including real people standing in the context area, so the
  absolute values (2.40 / 2.68) are not pure "ghost" measures. The
  comparison is still apples-to-apples (same crop, both candidates).
- One raced crop is a sample of one. PowerPaint may still win on other
  large patches; it did not win the only one this testset produced.
