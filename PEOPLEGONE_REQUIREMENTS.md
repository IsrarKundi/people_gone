# PEOPLEGONE — REQUIREMENTS (Single Source of Truth)

**Version:** 1.0 — 2026-10-12
**Author:** Lead Architect (synthesis of six specialist research memos, 2026-10-12, in `research/`)
**Audience:** The AI coding agent building this app (Google Antigravity) and the solo developer reviewing its work.
**Status:** NORMATIVE. If any research memo, comment, or earlier document conflicts with this file, **this file wins**. Research memos are non-normative background.

## How to use this document

1. Read §1–§3 before writing any code. Read the section you are implementing before each task (§14 lists tasks in order; each task cites its sections).
2. Every requirement with an ID (`FR-xx`, `NFR-xx`, `CMP-xx`) is testable. A task is done only when its acceptance criteria (§13) pass.
3. **Never invent a decision that this document already makes.** If something is genuinely unspecified, choose the option that is (a) simpler, (b) cheaper to run, (c) more private — in that order — and record it in `docs/architecture/` as an ADR.
4. Labels used throughout: **Verified** = checked against a named source on 2026-10-12 · **Estimate** = arithmetic on stated assumptions · **Assumption** = a decision made without direct evidence; treat as changeable only via ADR.
5. Hard rules that override everything else in this doc:
   - NEVER use the words "Magic Eraser" or "Magic Editor" in the app name, store metadata, in-app copy, or marketing. Never market watermark or logo removal, anywhere, ever.
   - NEVER request full photo-library permission. System photo picker only (§11).
   - NEVER put any AI-vendor or server secret in the mobile app or the git repo.
   - NEVER silently downscale a user's photo. Output dimensions always equal input dimensions (§5, FR-14).
   - NEVER log, store in analytics, or send to any third party the content of a user's photo.

---

## 1. Product summary, positioning, target user

### 1.1 The one-job promise

> **Every background person, gone in one tap, at full resolution — on the phone you already have.**

PeopleGone does exactly one job: the user picks a photo, the app automatically finds **all background people**, the user confirms with **one tap**, the people are removed with AI inpainting, and the result is saved at the **original full resolution**. It is not a photo editor. It has no filters, no stickers, no object library, no social features.

Real-world example: a family's one good photo at a landmark has six strangers behind them. Instead of 20 minutes of brushing in a general editor, the parent opens PeopleGone, sees the six strangers highlighted and their own family protected, taps **Remove People**, checks the result, and saves the full-size photo for the family album.

### 1.2 Why this product can win (evidence summary)

- The exact search phrase `remove people from photo` is effectively unowned: the iOS #1 result in the US/GB/IN stores has **1 rating** (Verified, iTunes Search API, 2026-10-12, `research/market-aso.md`). Head terms like `remove objects` (leaders with 122K–129K ratings) are **not** targeted at launch.
- The free built-in tools exclude most of the world (all Verified, 2026-10-12):
  - **Apple Clean Up** requires an Apple Intelligence phone — **iPhone 15 Pro or newer**. Older iPhones have no built-in removal at all.
  - **Google Magic Editor** (the high-quality generative tool) is capped at **10 free saves/month** for non-Pixel / non-Google One Premium users. (Google's simpler Magic Eraser is *not* capped — never claim it is.)
  - **Cleanup.pictures** (web) is free only up to **720px** exports; full resolution costs $5/mo or $36/yr.
  - **SnapEdit**, the strongest focused rival (~21M Android downloads, 4.46★), auto-detects *objects in general*, has **no main-subject protection**, and its free tier is capped at 1,600px **with a watermark and ads** (Verified, `research/competitors.md`).
  - **TouchRetouch**, the quality leader (58,146 US iOS ratings, 4.74★ — Verified live 2026-10-12; this corrects the mission's earlier ~7K figure), is **manual-brush** and is in an active pricing backlash: its lifetime licence was withdrawn and past buyers are being pushed to a subscription at export.
- Downloads ranking (2026-10-12): PeopleGone ranked **#1 of 10** mission finalists for realistic organic downloads — mass category flow (object-removal category leaders hold tens of millions of installs) combined with an ownable exact phrase.

### 1.3 Positioning (decided)

- **Claim:** one-tap removal of *all background people*, with the main subject protected, saved at full resolution, at one honest price.
- **Do NOT claim** superior inpainting quality vs Google/Apple/TouchRetouch. The counter-position is *workflow and access*: automatic, people-only, on any phone, no subscription tricks. Quality must merely be *good enough to post* — that is what the Phase 0 gate (§3) proves or kills.
- **Pricing honesty is a feature.** Prices and the free limit are stated before the user starts, never discovered at export. This is the shelf's loudest complaint pattern (Verified across `research/user-feedback.md` UF-08…UF-12 and `research/competitors.md`).

### 1.4 Target user

- **Primary:** Android owners on mid-range and older phones, and iPhone owners below iPhone 15 Pro — tourists, families, casual creators cleaning up travel/event photos.
- **Launch markets (Tier 1, decided):** US, UK, India, Indonesia, Brazil, Pakistan, Philippines (Android share 81–92% in most of these — Estimate, Counterpoint Q2 2026 via `research/market-aso.md`). Tier 2 (Phase 3+): Mexico/Spain (Spanish), Turkey, Vietnam, Argentina, Bangladesh, Germany, France.
- **Explicitly not targeted first:** Pixel owners with unlimited Magic Editor (they have almost nothing to buy), and professional batch/seller workflows (post-v1, §2.3).

### 1.5 Success definition for v1

- Pass the Phase 0 quality gate (§3) — without this, there is no v1.
- Launch on Google Play, reach and hold top-3 for `remove people from photo` in Tier 1 markets, store rating **≥ 4.3★** (the ASO swing variable, `research/market-aso.md`).
- Realistic download planning base: **800–2,500 installs/month at launch**, growing to 2,500–6,000 (Estimate, `research/market-aso.md`). The mission's earlier 8,000/month figure is a *mature* case, not a launch plan.

---

## 2. Scope

### 2.1 MVP in scope (v1.0, Android)

1. System photo picker (one photo at a time) — no library permission.
2. Cloud analysis: automatic detection of **every person**, main-subject proposal, per-person keep/remove overlay.
3. One-tap **Remove All** (removes every person marked "remove"), per-person toggles before executing.
4. Shadow-inclusive masking (§6.4) and automatic second-pass ghost check with one retry.
5. Manual rescue brush (add/erase mask, pinch-zoom, undo/redo) that re-runs inpainting on the affected region only.
6. Before/after compare (hold-to-view-original + slider).
7. Full-resolution save as a **copy** (original untouched), share sheet, on-device history.
8. Free tier: **10 full-res saves per calendar month** (§9). Unlimited watermark-free previews.
9. Pro entitlement: Annual / Monthly / Lifetime via RevenueCat (§9), restore purchases.
10. First-upload consent sheet, result-screen disclosure line, **Report this result** flow (§11).
11. Settings: free-saves counter, privacy policy, delete-my-data, licences, support link.
12. First-party job telemetry (metadata only — never image content, §12).

### 2.2 Explicitly out of scope for v1 (do not build, do not stub)

- General editing: filters, adjustments, text, stickers, background replacement, beautify.
- Removing arbitrary objects in the *automatic* flow (brush mode may be used on any region by the user, but marketing and auto-detection are people-only).
- Video, Live Photos, burst/batch processing (batch is Phase 3, §2.3).
- Accounts, sign-in, cloud photo library, cross-device sync.
- Ads (anywhere, any tier).
- On-device AI processing (revisit Phase 3, §15 D12).
- Watermark/logo removal features or claims.
- iOS release (Phase 2, §2.3 — but code must stay iOS-clean, §6.2).

### 2.3 Later phases (decided order)

- **Phase 2 — iOS fast-follow:** same codebase, StoreKit via the same `PurchaseService`/RevenueCat, iOS 15 floor. Trigger: Android live + real-user quality holding (save-rate and report-rate within §12 thresholds) + unit economics not underwater.
- **Phase 3 — growth:** Tier 2 localisations (listings first, then UI), batch mode for holiday sets, possible on-device preview tier (MI-GAN class) if it passes the same blind harness.

---

## 3. Phase 0 — the mandatory quality gate (build this FIRST)

**Purpose.** For the smallest possible spend, answer the only question that decides this product: *can the chosen pipeline remove background people well enough that blind raters judge the results postable next to the free native tools?* A gate that cannot fail is not a gate — the STOP outcome is a legitimate, money-saving result.

### 3.1 What to build in Phase 0 (and nothing else)

1. A Python worker implementing the §6.4 pipeline end-to-end (detector → SAM 2.1 masks → mask prep → LaMa inpainting on native-res crops → composite), callable as `process(photo, keep=[ids]) → result.jpg + job_metadata.json`. Deploy on RunPod Serverless; local/Replicate LaMa is allowed for first smoke tests only.
2. A batch runner: folder of test photos + hand-written ground truth per photo (keeper IDs, remove IDs, shadow locations) → produces primary results at identical dimensions/JPEG quality, EXIF stripped, randomised filenames.
3. A local static blind-review page: Original / Result A / Result B (randomised order per photo and per rater), 100%-zoom toggle, scoring form writing CSV/JSON (§3.3).
4. The Clipdrop comparison arm (§6.5): same masks through Clipdrop Cleanup `quality` mode inside the crop loop, using its free developer credits — the whole gate fits in free/near-free tiers at this set size.
5. **Licence verification task (blocking):** confirm and archive in `docs/licences/` the exact licences of every shipped weight: SAM 2.1 checkpoints (Apache 2.0 — Verified), the chosen detector checkpoint, and big-lama as distributed via IOPaint. **Ultralytics YOLO models must not be used** (AGPL-3.0 / paid Enterprise only — Verified).

**Do NOT build in Phase 0:** the Flutter app beyond a throwaway picker if needed, accounts, payments, store assets.

### 3.2 The fixed test set — 30 photos, frozen before any result is seen

Real phone photos (developer's + donated with written permission, 12 MP+), numbered and frozen. Composition (from `research/technical-image-processing.md` §8.2 + `research/user-feedback.md` UF-20/UF-21):

| Category | n |
|---|---|
| Simple backgrounds (sea/sky/sand/grass/plain wall) | 6 |
| Architecture/landmarks (lines, tiles, bricks, railings) | 5 |
| Crowds/street scenes (keeper must survive untouched) | 5 |
| Overlap (background person touching/partly behind keeper) | 4 |
| Strong cast shadow from a removed person | 3 |
| Small/distant people (viewpoint tourists) | 3 |
| Large background person (>20% of frame) | 2 |
| Reflection present (window/water/mirror) | 2 |
| **Total** | **30** |

Cross-cutting: at least 2 photos must be low-light/noisy, and at least 2 must contain hair/fine-edge stress (wires, fences, text). This same frozen set becomes the production regression set (§13.3).

### 3.3 Blind protocol and scoring

- **Competitor arms:** Google (Magic Eraser *and* Magic Editor logged as separate engines — never averaged) and Apple Clean Up (requires an iPhone 15 Pro+ / Apple Intelligence device). If no Apple device is available, run the Google arm only and label the result one-armed — never fake the second arm.
- **Raters:** 5–10 people who did not build the pipeline, including 2–3 non-technical phone-photo users.
- **Per result, score:** (1) removal completeness 1–5, (2) fill believability at normal size 1–5, (3) fill believability at 100% zoom 1–5, (4) keeper untouched — pass/fail (any keeper damage = critical defect), (5) "Would you post this photo?" — yes/no. Record per result: end-to-end seconds, GPU-seconds/credits, computed cost.

### 3.4 Decision rule (written before the test; do not renegotiate after)

- **GO** — build the app on the primary pipeline — if ALL hold:
  - "Would post" ≥ **70%** overall **and** ≥ **90%** on the 6 simple-background photos;
  - primary wins-or-ties the native tool in ≥ **40%** of head-to-heads;
  - **zero** keeper-damage critical defects from the default proposal;
  - median end-to-end ≤ **20 s** warm; measured all-in cost ≤ **$0.01/photo**.
  (This operationalises the mission's original rule — blind test, comparable on ≥7 of 10 — with measurable thresholds; see Decisions Log D7.)
- **ITERATE** — change exactly one stage and re-run the *same* 30 photos:
  - fills fail, segmentation clean → swap inpaint arm (Clipdrop quality → diffusion hard-tile for hard crops);
  - segmentation fails, fills good → fix detection (larger SAM 2 checkpoint, higher analysis resolution, Mask2Former comparison arm);
  - shadows dominate complaints → invest only in §6.4 shadow handling first.
- **STOP — do not build the app** if, after one inpaint swap **and** one segmentation fix: "would post" stays < **50%**, **or** natives win > **80%** of head-to-heads, **or** the overlap category is unacceptable in > 75% of its photos on *every* engine including the natives. Report the finding; polishing an app around a failed core is forbidden.

### 3.5 Fallback switch (pre-decided)

If the gate fails *on LaMa fill quality only*, the fallback engine is **Clipdrop Cleanup (quality mode) fed the same masks inside the crop loop** (§6.5), re-tested in the same harness. If Clipdrop also fails or its written commercial price (a precondition, §6.5) makes all-in cost > $0.02/photo, escalate hard crops to a diffusion tile pass and re-test. If all arms fail the STOP rule, stop.

---

## 4. User flows and screen-by-screen specification

### 4.1 Golden flow (the only flow that matters)

`Home → Pick photo (system picker) → [first time only: Consent sheet] → Uploading → Analysing → Proposal (overlay, keep/remove) → [optional: toggle people / brush] → Removing (progress) → Result (compare) → Save (credit check) / Share → Home (history updated)`

### 4.2 Screens

**S1 — Home.** Shows: app wordmark, one primary button **"Pick a photo"**, free-saves counter for free users ("7 of 10 free saves left this month") or "Pro" badge, history grid (on-device, newest first, thumbnail + date), Settings icon. *Empty state (no history):* one line explaining the one job + the Pick button. *No other content.* No feed, no ads, no upsell banner.

**S2 — Consent sheet** (modal, shown once per `consent_version`, before the first upload only). Exact wording in §11.2. Buttons: "Continue and upload my photo" / "Cancel" (cancel costs nothing; user returns to Home). Never pre-ticked, never bundled with Terms acceptance.

**S3 — Uploading / Analysing.** Progress bar for upload (%), then an indeterminate "Finding people…" state. Cancellable. If offline: explain and offer "Wait for connection" (job stays queued locally, §6.7). Target: analysis result ≤ 5 s warm after upload completes (Estimate).

**S4 — Proposal.** The photo with per-person overlays: people proposed for removal in **red**, the protected main subject(s) in **green**, each tappable to toggle keep/remove. Primary button: **"Remove N people"** (live count). Secondary: **Brush** (S5). If a background person overlaps/touches the subject, show a one-line quality-risk note ("This person overlaps your subject — edges may need a touch-up"). If analysis found **no** background people: plain message ("There's nobody in the background to remove") + offer Brush mode. If the only person **is** the subject: never propose removing them.
*Keeper rule (hard):* the default proposal **never** includes the main subject. When subject-vs-background confidence is low, default to KEEP and say so (UF-02).

**S5 — Brush.** Full-screen photo, pinch-zoom, two tools (Add to removal / Erase from removal), brush-size slider, Undo/Redo. "Done" returns to S4 with the edited mask. Available before removal (adjust proposal) and after a result (repair a region, §5 FR-09).

**S6 — Removing (progress).** Per-person progress ("Removing person 2 of 4…"), cancellable, UI never frozen, job survives backgrounding (poll on resume). Warm target: whole job median ≤ 20 s; cold start may reach ~45 s — show honest progress, never a spinner with no state (UF-17).

**S7 — Result.** Edited photo default; **hold-to-view-original** and a before/after slider (UF-14). Buttons: **Save** (primary), **Share**, **Brush fix** (repair a leftover region), **Undo step** (restore one removed person, FR-10), **Report this result** (small, but present — §11 CMP-06). One disclosure line: "Processed securely · Original deleted from server · Report this result". If the second-pass check (§6.4) suspects a leftover ghost/shadow, say so here with a "Try fix" action — never silently save a suspected ghost.

**S8 — Paywall.** Shown ONLY when: user taps Save with 0 free saves and no Pro (§9.3), or user opens it deliberately from Settings/Home badge. Shows the result preview (already earned — never blurred/watermarked), the three plans (§9.2) with Annual pre-selected and Lifetime equally visible above the fold, price + renewal terms in plain language, Restore Purchases, and "Not now" (result stays available for 24 h, §9.3). Never shown before the user has seen a first successful result.

**S9 — History.** On-device grid of the user's saved clean photos (files in app storage) with date; tap → view, share, delete. Deleting removes the local file only. No cloud history exists — say so in one line ("History lives only on this phone").

**S10 — Settings.** Free-saves counter / Pro status + Manage subscription (deep link to store), Restore Purchases, Privacy Policy, Consent details, **Delete my data** (§11 CMP-09), Open-source licences, Support (mailto), app version, processing-provider name (from config).

### 4.3 Global states and edge cases (apply to every screen)

- **Loading:** skeleton or progress with a named stage; never a blank screen > 1 s.
- **Error:** plain-language message + one recovery action (Retry / Pick another photo / Go Home). Technical error codes go to logs, never to the user.
- **Empty:** every list has an empty state that teaches the one job in one line.
- **Huge photo:** inputs up to **100 MP / 60 MB** are accepted (Assumption — Phase 0 must verify a 50 MP case). Above that: explicit error ("This photo is larger than PeopleGone can process") — **never** a silent downscale.
- **Interruption:** leaving mid-job and returning resumes status polling; a completed job's result remains downloadable for 24 h.
- **Rotation/theme:** portrait + landscape photo viewing supported; dark mode follows system.

---

## 5. Functional requirements (numbered, testable)

**Detection & proposal**
- **FR-01** Tapping "Pick a photo" opens the **system photo picker** (Android Photo Picker / iOS PHPicker via `image_picker`). The app must never request `READ_MEDIA_IMAGES` or full-library access.
- **FR-02** On first upload per `consent_version`, the consent sheet (S2) blocks upload until accepted. Declining leaves all local features usable except processing.
- **FR-03** Analysis returns **every** detected person as a separate instance with a mask, each labelled keep/remove by the §6.4 heuristic. The proposal (S4) renders all instances before anything is removed.
- **FR-04** Default proposal: main subject(s) = KEEP (never pre-selected for removal, UF-02); every other person = REMOVE. Low subject-confidence → KEEP + warning.
- **FR-05** Tapping any person toggles keep/remove; the Remove button count updates immediately.
- **FR-06** If analysis finds 0 people, or only the subject, the app states that plainly and offers Brush mode. No processing credit/save is consumed, ever, for an empty job.

**Removal & repair**
- **FR-07** "Remove N people" executes removal of exactly the REMOVE set: mask union → shadow expansion → inpaint crops → composite (§6.4). Progress is reported per person/cluster; the job is cancellable; cancelling consumes nothing.
- **FR-08** Removal masks include the person's cast shadow and contiguous held/attached belongings by default (UF-03); the expanded mask is what the overlay shows.
- **FR-09** After a result, Brush fix lets the user paint any missed region (leftover limb, reflection, photobomber) and re-runs inpainting on **that region's crop only**. Reflections are a brush-mode job in v1 — automatic reflection removal is not promised (§15 D11).
- **FR-10** Undo/redo within the session, including **per-person undo** (restore one removed person without restarting) (UF-13).
- **FR-11** A failed/disliked re-run of the same photo/region never consumes a save credit (UF-10). Retries are free and uncounted.
- **FR-12** Face rule (UF-16): removing a person removes the whole person. The app must never pixelate a face, generate a substitute face, or silently remove a face partially as a fallback.

**Result, save, share**
- **FR-13** Result screen provides hold-to-compare and a before/after slider (UF-14).
- **FR-14** **Full-resolution save:** the saved file has **identical pixel dimensions** to the input; only inpainted regions differ; everything outside the masks is bit-identical to the decoded original before final encoding (composite rule, §6.4). Saved as a **copy** — the original file is never modified (UF-06, UF-07).
- **FR-15** Metadata on save: orientation applied correctly; ICC/colour profile and non-location EXIF preserved; **GPS/location metadata always stripped**. The save screen states this in one line (UF-07).
- **FR-16** Save consumes **1 free save** (free tier) at the moment of save — never at processing. Previews are unlimited and watermark-free on screen (§9.1).
- **FR-17** Share uses the system share sheet on the saved (or 24 h-retained) result file. No watermark on any export, free or paid (UF-08).
- **FR-18** History (S9) stores saved results on-device only, with thumbnails and dates; the user can view, share, and delete entries.

**Entitlement & account-free identity**
- **FR-19** No sign-up or account exists. Identity = Supabase anonymous-auth install ID (§7). Purchases restore via RevenueCat + store account (FR-21).
- **FR-20** Free-saves balance is read from the **server ledger** (§7) — the on-device counter is a display hint only. Balance is shown on Home and Settings.
- **FR-21** Restore Purchases must restore Pro on reinstall/new device via the store account through RevenueCat, with no support contact needed.
- **FR-22** If the store/receipt validation fails, the app shows a plain error and a Retry — it must never silently drop a paid entitlement.

**Settings, privacy, support**
- **FR-23** Report this result (S7) submits job ID + optional user note (+ the result image **only** if the user explicitly attaches it) — §11 CMP-06.
- **FR-24** Delete my data (S10) deletes the install's server-side data (ledger, job metadata, any retained files) and confirms completion in-app (§11 CMP-09).
- **FR-25** Every price/limit the user can hit is displayed **before** processing starts (Home counter, S4 line). No paywall may appear after an edit without the limit having been visible beforehand (UF-08).

**Non-functional requirements**
- **NFR-01** Warm end-to-end (upload complete → result): median ≤ 20 s, p95 ≤ 45 s including one cold start (Estimate targets; Phase 0 verifies the median).
- **NFR-02** Analysis (upload complete → proposal): ≤ 5 s warm (Estimate).
- **NFR-03** The app must remain usable on a 3 GB-RAM mid-range Android device; full-resolution bitmaps are never held in Dart memory (files + downscaled previews only, §6.4).
- **NFR-04** All network traffic is TLS; all provider keys exist only server-side (§7.3).
- **NFR-05** `flutter analyze` clean and `flutter test` green are required for every completed task (§13, §14).

---

## 6. Technical architecture

### 6.1 Stack (pinned — do not substitute without an ADR)

| Layer | Decision |
|---|---|
| Framework | Flutter, **one exact stable version** pinned via FVM (`.fvmrc` committed; record the version in `AGENTS.md` and CI). Dart = the bundled Dart for that Flutter. |
| State management | **GetX** — one approach, everywhere, no mixing (developer's house style from the Darzi project). |
| Photo picking | `image_picker` (system pickers only). `permission_handler` must NOT be used for photos. |
| Networking | `dio`, wrapped by a single `ProcessingApi` service (uploads with progress + cancellation; TLS only). UI code never calls the network directly. |
| Local storage | App-documents directory for history files + a small local index; `flutter_secure_storage` for tokens/consent record. |
| Billing | **RevenueCat** (`purchases_flutter`) behind a `PurchaseService` interface (§15 D4). UI never calls RevenueCat/store APIs directly either — always via `PurchaseService`. |
| Utilities | `share_plus`, `path_provider`, `connectivity_plus` (offline queue state). |
| Android build | targetSdk / compileSdk **36**, minSdk **24**, AAB, R8/minify on, Play App Signing, 16 KB page-size ready. |
| iOS build (Phase 2) | Deployment target **iOS 15.0** (keeps iPhone 8/X), Xcode 26 / iOS 26 SDK, `PrivacyInfo.xcprivacy` present. |
| Lint | `flutter_lints` + strict casts/inference; `pubspec.lock` committed, never hand-edited. |

### 6.2 Project structure (create exactly this — from `research/platform-requirements.md` §5.1)

```
peoplegone/
├── AGENTS.md                    # standing rules for the coding agent (§6.3) — read first, every session
├── README.md
├── PEOPLEGONE_REQUIREMENTS.md   # this file — the only normative spec
├── docs/
│   ├── compliance/ (privacy-policy.md, store-forms.md, consent-copy.md, record-of-processing.md)
│   ├── architecture/            # ADRs
│   ├── licences/                # archived model-weight licences (§3.1 task 5)
│   └── release/ (play-submission-checklist.md, appstore-submission-checklist.md)
├── app/                         # Flutter app
│   ├── lib/ (main.dart, config/, core/, features/{picker,processing,result,history,paywall,settings}, services/)
│   ├── test/ (unit/, widget/, fixtures/)
│   ├── integration_test/
│   ├── android/                 # manifest: NO media permissions
│   └── ios/
├── server/                      # Supabase config + Edge Functions + worker pointer (§7)
│   └── worker/                  # GPU worker container (Python) — host-agnostic (§6.4)
└── .github/workflows/           # CI: analyze + test on PR; release build on tag
```

Rules: feature folders own their UI + logic; **services are the only code that touches network/billing/storage**; no file over ~400 lines; iOS-clean from day 1 (no Android-only plugins/channels in v1; monthly manual iOS build to prove it still compiles).

### 6.3 AGENTS.md constitution (write this file in Build Task 1)

- **NEVER:** add a media/library permission · commit any secret/key/keystore/`.env` · call an AI/GPU vendor from the client · log image data or image URLs · hard-code prices or the provider name (both come from config) · use "Magic Eraser"/"Magic Editor" anywhere · silently downscale output.
- **ALWAYS:** cite the requirements section you implement in the commit/PR · run `flutter analyze` + `flutter test` before declaring done · update `docs/compliance/store-forms.md` in the same change if data behaviour changes · keep files < ~400 lines · stop at human-only steps (store accounts, legal agreements, entering secrets, pressing Submit) and leave them as a checklist instead.
- Secrets: client config (non-secret only — API base URL, provider display name, `consent_version`, support email, privacy URL) via `--dart-define-from-file`; prod config injected by CI. `.gitignore` must cover `.env*` (except `.env.example`), `**/key.properties`, `**/*.jks`, `**/*.keystore`, `server/.env`.

### 6.4 The processing pipeline (the heart of the product — implement exactly this shape)

Two server stages over **one upload** (the original is uploaded once; both stages use it):

**Stage A — Analyse** (target ≤ 5 s warm)
1. Decode the original server-side, applying EXIF orientation. Keep the original file untouched in ephemeral storage (§7.4).
2. Build an analysis copy (long side 1,024–1,280 px). Run a COCO person **detector** (Apache/permissive-licensed checkpoint only — §3.1; RT-DETR-class) → one box per person.
3. Prompt **SAM 2.1 (tiny/small)** with each box → one instance mask per person.
4. Keeper heuristic (tune in Phase 0; starting weights — Assumption): score = 0.4·relative area + 0.25·centrality + 0.2·face/upper-body sharpness + 0.15·foreground cues. Top instance = keeper; if the top two overlap/touch at similar scale (couple photo), both are keepers. All others = REMOVE proposal.
5. Return instance polygons (preview scale) + keeper proposal to the app. The app renders overlays from this — **no full bitmap work happens on the phone.**

**Stage B — Process** (runs on user confirm; median ≤ 20 s warm)
1. Union the REMOVE masks. **Dilate** by 3–8% of each person's bounding-box width (floor ~8–16 px at working resolution; larger on simple backgrounds, smaller on keeper-shared boundaries). Fill interior mask holes.
2. **Shadow expansion (default ON):** grow each mask into adjacent dark, low-saturation regions touching the person's lower boundary/feet (heuristic — Assumption), constrained plausibly outward from the feet. This expanded mask is what S4/S5 display.
3. Per removed person (or overlapping cluster): crop the **native-resolution** bounding box + 40–60% context margin (min ~256 px). If the crop's long side > ~1,536 px, split into sequential overlapping sub-crops. **No model ever receives the whole 12–50 MP frame.**
4. Inpaint each crop with **LaMa (big-lama via IOPaint)** — single forward pass per crop.
5. **Second-pass check:** run the person detector on the composited result. A surviving human-shaped residual (or person-shaped dark shadow) triggers **one** automatic retry of that crop with larger dilation. If it still fires, deliver the result with the S7 "suspected leftover — Try fix" notice.
6. **Composite:** paste only the inpainted masked pixels onto the decoded original at native resolution, with a 2–6 px (native-scaled) alpha feather on the paste boundary. Mask sent to the inpainter is never feathered.
7. Encode JPEG quality ~95 at the input's exact dimensions; preserve ICC + non-location EXIF; strip GPS (§5 FR-15).
8. Deliver via signed URL; mark the original for deletion on delivery (§7.4).

**Worker implementation:** one portable Docker container (Python): detector → SAM 2.1 → mask prep → LaMa → composite. Hosted on **RunPod Serverless** (16 GB GPU tier, $0.00016/s — Verified 2026-10-12; scale-to-zero, 0 always-on workers; FlashBoot on). The container and handler must stay host-agnostic (no RunPod-specific APIs in worker code) so **Modal** is a deployment change, not a rewrite. **Ops trap (Verified, RunPod docs):** endpoints idle 7 days get max-workers set to 0 — a scheduled health-ping is a launch-checklist item (§14, Phase 5).
**Concurrency/memory (server):** work crop-by-crop, stream decode where possible, cap concurrent jobs per worker, queue rather than OOM on 50 MP inputs (~150 MB decoded).

### 6.5 Fallback engine — Clipdrop Cleanup (pre-decided, §3.5)

- Role: (a) production failover if the primary endpoint is down/overloaded, (b) Phase 0 reference arm, (c) possible hard-photo escalation if the gate proves it better on structured backgrounds.
- Integration: consumes the **same mask PNG** inside the same crop loop (respect its 16 MP / 30 MB per-call cap — Verified). No second segmentation system.
- **Mandatory preconditions before it carries production traffic:** (1) written per-credit price from Jasper/Clipdrop (no public API price exists — Verified), (2) written confirmation of commercial use of outputs in a consumer photo app, (3) it passes the §3 harness at `quality` mode.
- Routing is a server config flag (`PROCESSOR=primary|clipdrop`), never a client change.
- If Clipdrop pricing/terms fail: fallback-of-fallback is queueing on the primary (degraded latency, honest in-app message) — never silently shipping a worse result. SnapEdit API is **not** a production dependency (vendor self-benchmarks only, invite access, unpublished keep-control/resolution/terms — `research/technical-image-processing.md` §3.6); it may be run as a Phase 0 bonus arm only.

### 6.6 Explicitly rejected approaches (do not revisit without an ADR + new evidence)

remove.bg and PhotoRoom API (they do background *removal/cutout*, not inpainting — wrong operation; remove.bg also reported retiring 2026-12-01) · whole-photo API round trips as the save path (breaks FR-14) · Ultralytics YOLO-seg (AGPL) · diffusion inpainting as the *default* engine (10–100× cost/latency + hallucinated-people risk; allowed only as a hard-crop retry arm if Phase 0 proves it earns its cost) · on-device inpainting as the v1 engine (§15 D12) · Adobe Firefly (no self-serve removal API).

### 6.7 Offline, queueing, errors, retries

- **Offline at pick time:** photo stays local; the job is queued in-app and starts when connectivity returns. Nothing is lost; no credit/save is touched.
- **Upload failure / timeout:** automatic retry with backoff (3 attempts); the job ID is **idempotent** (client-generated per photo-hash + settings) — a retry never creates a second billable job (§8).
- **Stage timeout:** analysis > 30 s or processing > 90 s → the app shows the failure state with Retry; the server job may still complete — on Retry, poll the same job ID first before creating a new job.
- **Server down / overloaded:** jobs queue server-side with position-free honest copy ("Busy — your photo is in line"). If both primary and fallback are down, queue; never fabricate a result.
- **App killed mid-job:** on relaunch, resume polling the open job ID; completed results remain downloadable 24 h (§7.4).

---

## 7. Data model and backend (decided — minimal backend, no accounts)

### 7.1 Decision

PeopleGone has a **minimal backend**, because three things cannot live in the app: GPU-vendor keys (extractable from any binary), the free-saves ledger (bypassable by reinstall if client-side), and the GPU worker itself. The backend is:

- **Supabase** (Postgres + Edge Functions as the API gateway + private Storage buckets + Anonymous Auth). Free tier during development/closed test; **Pro $25/mo from public launch** (decided, `research/costs-monetization.md` §6).
- **RunPod Serverless worker** (§6.4) — the only component that touches image pixels besides the app.
- **RevenueCat** webhooks → entitlement sync into the ledger.

There are **no user accounts** (§5 FR-19). Identity = anonymous-auth install ID.

### 7.2 Data model (Postgres)

| Table | Key fields | Notes |
|---|---|---|
| `installs` | `id` (anonymous auth uid), `platform`, `app_version`, `created_at`, `consent_version` + `consent_at` | One row per install. No email, no name, ever. |
| `credits_ledger` | `install_id`, `period` (`YYYY-MM`, UTC), `free_saves_used`, `pro_status` (cache of RevenueCat), `pro_source`, `fair_use_saves_used` | The **only** source of truth for saves balance. Decrement atomically **at save time** (§9.1); refund automatically if delivery of the result file fails. |
| `jobs` | `id` (client-generated idempotency ID), `install_id`, `status` (queued/analysing/awaiting_confirm/processing/done/failed/expired), `people_count`, `removed_count`, `mask_area_ratio`, `gpu_seconds`, `cost_estimate_usd`, `retry_count`, `ghost_check_fired` (bool), `processor` (primary/clipdrop), `created_at`, `expires_at` | **Metadata only. No image data, no image URLs beyond expiry.** Powers §12 metrics and §8 cost accounting. |
| `reports` | `id`, `job_id`, `install_id`, `note`, `has_user_attached_image` (bool), `created_at` | Report-this-result (§11 CMP-06). Attachment stored only if the user explicitly attached it; 30-day retention. |
| `consent_records` | `install_id`, `consent_version`, `accepted_at`, `provider_name_shown` | Evidence for §11 CMP-03. |

Storage buckets (private, signed URLs only, versioning OFF): `uploads/` (originals), `results/` (cleaned outputs). Lifecycle/TTL jobs enforce §7.4 — deletion is code (scheduled Edge Function), not manual cleanup, and each deletion run is logged (counts only).

### 7.3 API (Edge Functions — the app talks only to these)

| Endpoint | Behaviour |
|---|---|
| `POST /jobs` | Validates install + velocity caps (§8), returns `job_id` + signed upload URL. Idempotent on the client job ID. |
| `POST /jobs/{id}/analyse` | Triggers worker Stage A; returns instance polygons + keeper proposal (or a typed failure: no_people / only_subject / too_large). |
| `POST /jobs/{id}/confirm` | Body: keep/remove per instance + optional brush-mask delta (PNG at preview scale). Triggers Stage B. |
| `GET /jobs/{id}` | Status + (when done) signed result URL + job metadata for the result screen. |
| `POST /jobs/{id}/save` | **The credit gate:** checks ledger (Pro? fair-use? free saves left?), decrements atomically for free users, returns the full-res result URL. If no entitlement: returns `PAYMENT_REQUIRED` — the app shows S8; the result stays downloadable for 24 h if the user pays within the window, without reprocessing. |
| `POST /jobs/{id}/report` | Report-this-result (note + optional explicit image attachment). |
| `DELETE /my-data` | Deletes the install's rows + any retained files; returns confirmation (FR-24). |
| RevenueCat webhook | Updates `credits_ledger.pro_status` on purchase/renewal/refund/expiry. Refund → entitlement revoked at webhook, not at next app open. |

**Security rules (blocking):** no vendor key ever leaves the server; the gateway validates entitlement + caps **before** spending GPU time; Play Integrity attestation checked on `POST /jobs` when available — attestation failure routes to a slower queue, never a hard block (false positives on low-end devices are a ratings risk).

### 7.4 Retention (implement exactly — this is also the public privacy promise)

| Data | Rule |
|---|---|
| Original photo (successful job) | Deleted when the result is delivered. |
| Original + result (failed/abandoned/undelivered) | Auto-delete **24 h** after upload. |
| Cleaned result (server copy) | Deleted on delivery confirmation or at 24 h, whichever is first. The user's copy lives on their device. |
| Report attachment (user-sent only) | Max **30 days**, then deleted. |
| Server/security logs | **30 days**; request ID, timestamps, sizes, status codes — **no image content, no EXIF, no outliving URLs**. |
| Ledger / entitlement records | Life of the entitlement + tax/accounting period; contains no photo data. |
| Backups | Processing buckets are excluded from long-cycle backups (or backups inherit the same 24 h TTL) — a backup must never resurrect a "deleted" photo. |

---

## 8. Cost model and cost protection

### 8.1 Unit economics (decided planning figures)

- **Primary pipeline cost: budget at $0.006/photo all-in** (conservative ceiling — Estimate). Basis: RunPod 16 GB tier $0.00016/s (Verified) × 3–8 GPU-seconds/job + idle/cold-start waste + 10–20% retry uplift (`research/technical-image-processing.md` §4.4 estimates $0.002–0.004; the costs memo's $0.0010 is the warm best case — planning uses the ceiling, §15 D2).
- **Volume table (primary pipeline at $0.006 ceiling):**

| Photos / month | GPU cost | + Supabase | Total infra (Estimate) |
|---|---|---|---|
| 100 | $0.60 | $0 (free tier, dev) | ~$1 |
| 1,000 | $6 | $0–25 | ~$6–31 |
| 10,000 | $60 | $25 (Pro) | ~$85 |
| 100,000 | $600 | $25 + egress headroom | ~$650–750 |

- **Free-tier worst case (launch base):** 8,000 installs, *every* installer burns all 10 free saves = 80,000 photos ≈ **$480** one month — covered by circuit breakers (§8.2) and by the base-case revenue cohort (~$2,930 net — Estimate, `research/costs-monetization.md` §3.4). Typical case (50% activate, avg 4 saves) ≈ 16,000 photos ≈ **$96**.
- **Why not a premium API:** FLUX-class inpainting at ~$0.05/photo makes the same free tier cost ~$4,000–5,025/month at 100k photos and gives a Lifetime buyer only ~595 funded photos. Premium APIs + this pricing + no cap must never ship together (§15 D1/D5).
- **Fixed costs:** Google Play $25 one-time; Apple $99/yr (Phase 2); RevenueCat $0 until $2,500 monthly tracked revenue, then ~1%; store commission **15%** under both small-business programs (enrol **before** submission — human-only step).
- **Dedicated GPU crossover (do not act early):** an always-on worker (~$285–431/mo) only beats serverless at roughly **50,000–65,000+ photos/month sustained** (Estimate, both memos agree in range). Below that, serverless is the cost strategy; the portable container makes the later move a weekend job.

### 8.2 Cost-protection rules (all are launch requirements, implemented as gateway config)

1. No provider keys in the client; gateway validates entitlement + balance **before** spending (§7.3).
2. Server-side ledger is the only truth for saves (§7.2); on-device counters are display hints.
3. Identity without an account wall: anonymous auth + device signals + Play Integrity (slow-queue on failure, never hard-block).
4. **Velocity caps (all tiers):** max 20 jobs/hour and 100 jobs/day per install identity; free tier additionally max **20 processing jobs/day** (Assumption — far above human need, below farming value; tunable config, not hard-coded).
5. **Pro fair-use cap: 300 full-res saves/month included.** Beyond: jobs queue at low priority with honest in-app copy ("Heavy month — your extra cleans are queued"), with a warning shown at 80% usage. Never a surprise hard stop mid-album. This cap is what makes Lifetime honest on a metered pipeline.
6. Idempotency: one job ID per (photo hash + settings); retries and re-saves of an identical photo within the retention window hit the result cache and consume **neither** GPU spend **nor** a user save (UF-10).
7. Free and Pro get the **same output resolution and quality** — differentiation is count, never quality (§9.1).
8. **Budget circuit breakers (rolling cloud spend):** $50/day → alert the developer (same-day human look) · $150/day or $500/mo → free-tier processing switches to queue-only (Pro unaffected) · $300/day or $1,000/mo → free-tier processing pauses pending manual review, in-app copy says "Free cleans are paused for maintenance — back shortly" (never mention costs/abuse to users) · any single identity > 5% of daily jobs → auto-throttle that identity.
9. Auto-delete everything per §7.4 (cost, privacy, and marketing aligned).

---

## 9. Monetization specification (decided)

### 9.1 The model

**Freemium, count-based, no quality hostage-taking:**
- **Free: 10 full-resolution saves per calendar month** (resets on the 1st, UTC), no account, no watermark, no resolution cap. Matches the number users already know from Google Photos (10 free Magic Editor saves/month — Verified) and covers one real job completely — a completed first job is what produces 5★ reviews and shares.
- **Previews are unlimited and free.** Processing shows the result on screen (display-resolution preview); a **save** is what consumes the free allowance. Processing itself is bounded by §8.2 velocity caps, not by the save counter.
- **Retries/re-runs of the same photo never consume a save** (FR-11), and an identical-photo cache hit consumes nothing (§8.2 rule 6).

### 9.2 Prices and SKUs (US list; localise per §9.5)

| SKU | Store product | Price (Verified anchors + decision) |
|---|---|---|
| **Pro Annual (hero, pre-selected)** | `peoplegone_pro_annual` | **$19.99 / year** |
| **Lifetime Unlock (second tile, equally visible)** | `peoplegone_lifetime` (non-consumable) | **$34.99 one-time** |
| **Pro Monthly (third tile, not promoted)** | `peoplegone_pro_monthly` | **$4.99 / month** |

- One RevenueCat entitlement: **`pro`**, granted by any SKU. Pro = unlimited saves subject to the §8.2 fair-use cap (300/mo).
- **The mission's earlier $9.99 one-time price is rejected as a permanent SKU** (§15 D5): beside a $19.99/yr plan it makes the annual irrational and maximises lifetime GPU liability. $34.99 = 1.75× annual (standard utility lifetime multiple) and is fully funded on the primary pipeline: net of 15% commission ($29.74) covers ~4,900 photos even at the $0.006 ceiling — several lifetimes of casual use (Estimate).
- **No weekly SKU, ever** (3.4% 12-month retention benchmark + the category's most-hated pattern — Verified, RevenueCat State of Subscription Apps 2026). **No store free trial at launch** (Photo & Video has the lowest trial→paid conversion of any category, 22.2% — Verified, same source; the 10 free saves/month *are* the trial).
- Conversion planning: freemium download→paid median **2.1%** (Verified, RevenueCat 2026); plan cash flow on the pessimistic 0.7–1.0% (India/SEA-heavy mix) row, treat 2.1% as base and 2.8–3.5% as upside. Blended ARPPU at the decided mix ≈ $22.24 gross / ~$18.90 net per payer (Estimate).

### 9.3 Paywall triggers and behaviour

- Paywall (S8) appears **only** at: (a) Save tapped with 0 free saves and no Pro; (b) deliberate open from Home badge/Settings.
- **Never** before the user has seen a first successful result; **never** as a surprise — the remaining-saves counter is visible from Home onward (FR-25).
- The paywall shows the user's own result preview (unblurred, unwatermarked), all three plans above the fold, plain-language renewal terms ("$19.99/year, renews automatically, cancel anytime in Google Play"), Restore Purchases, and a working "Not now".
- If the user pays within 24 h, the held result saves **without reprocessing** (§7.3). If they don't, the server copy is deleted on the §7.4 clock and the app says so honestly.
- Grandfathering (UF-09, hard rule): **a Lifetime buyer can never be moved to a subscription.** Any future pricing change applies to new buyers only, automatically, in-product — no hidden restore steps.

### 9.4 Entitlement logic

RevenueCat is authoritative for purchase state; its webhook mirrors `pro_status` into the ledger (§7.3). The app checks entitlement via `PurchaseService` on launch and on resume. Offline: the last known entitlement is honoured for saves for up to 72 h (Assumption), then saves (not previews) pause until connectivity returns. Refunds revoke at webhook time.

### 9.5 Regional pricing

Use each store's local price tiers anchored to the US list (Google Play / App Store Connect local pricing), reviewing the India/Indonesia/Brazil/Pakistan/Philippines prices at submission so the local price is a plausible casual purchase (Estimate guidance: local annual ≈ the price of 1–2 local coffees, set via store tier equivalents — the developer confirms final local numbers at submission; the agent never hard-codes any price, §6.3).

---

## 10. ASO and store specification

### 10.1 Identity (decided)

- **App title (both stores):** `PeopleGone: Remove People` (25 chars)
- **Apple subtitle (Phase 2):** `Erase Strangers From Photos` (27 chars)
- **Play short description:** `Remove all background people in 1 tap. Full-res save, no brushing.` (66 chars)
- Title/subtitle tokens together cover `remove people from photo(s)` + `remove strangers from photo` with no repeated word (Apple indexes title+subtitle jointly).
- Alternatives to test only via store listing experiments, in this order: B `PeopleGone - People Remover` / subtitle `Remove People in One Tap`; C `PeopleGone: Erase People` (fix subtitle to avoid token repeat). A keyword-only unbranded title is **rejected** (generic, copycat-bait — `research/market-aso.md` §3.2).

### 10.2 Keyword architecture

- **Primary (build the listing around these):** `remove people from photo` · `remove person from photo` · `remove strangers from photo` · `people remover` / `person remover` (tokens).
- **Secondary (subtitle/keyword field/description; harvest as ratings build):** `remove objects from photo` (tokens for eligibility only — do **not** chase it as a primary), `photo eraser`, `object remover`, `remove unwanted people`, `remove background people`, `erase/delete people from photo` (verb variants).
- **Long-tail (description + localised listings + screenshot captions):** `remove tourists from photo` · `remove photobomb(er)` · `remove people from background` · `remove crowd from photo` · `remove strangers from travel photo`.
- **Apple keyword field (Phase 2, 90 chars, no repeats of title/subtitle words):** `tourist,photobomb,unwanted,background,retouch,clean,delete,object,vanish,picture,editor,ai`
- **NEVER in any metadata:** "Magic Eraser", "Magic Editor", "Clean Up" (as a feature name), or any competitor brand (TouchRetouch, Cleanup.pictures, Photoshop, SnapEdit…). Lower-case generic "clean up a photo" phrasing is allowed in description sentences only, never in title/subtitle.
- **Pre-submission validation (required task, ~$0):** real-device check of the in-store rank for `remove people from photo` in US + GB (the one verification debt from research — web search cannot certify in-store rank), plus a free-trial ASO pull (AppTweak/Astro) for the 4 primary phrases in US + GB. If the exact phrase shows near-zero modelled popularity in **both**, promote `remove person from photo` to lead phrase and record the change as an ADR.

### 10.3 Description outline (both stores; localise per §10.5)

1. **Line 1–3 (above the fold):** the one job + the differentiators + the honest free limit — "Remove every background person from a photo in one tap. PeopleGone finds them all, protects your main subject, and saves at full resolution. **10 full-res saves free every month. No watermark. No brushing.**"
2. How it works (3 steps, plain words).
3. Who it's for (older phones welcome — "works on the phone you already have"; no Apple Intelligence / Pixel required).
4. What Pro is (one short paragraph, prices, fair-use in plain words).
5. Privacy paragraph (exact store-listing disclosure, §11.2C).
6. What it does NOT do (not a general editor; doesn't remove logos/watermarks) — honesty here prevents 1★ expectation mismatches.

### 10.4 Screenshots and preview video plan

- 6–8 screenshots, **real pipeline outputs only** (also a store-policy duty): (1) before/after hero — landmark photo, strangers gone; (2) the proposal overlay — "It finds everyone. You tap once."; (3) subject protection — green keeper vs red removals; (4) 100%-zoom crop proving full-res quality; (5) honest pricing card — "10 free full-res saves every month. Then one honest price." (**The ASO draft claim "no monthly cap" is rejected — §15 D6; the listing states our own limit plainly**); (6) "Works on your phone" — mid-range Android in hand; (7) brush-fix demo; (8) privacy line screenshot.
- Preview video (15–30 s): the §10.4(1) demo as a single continuous flow, real outputs, no quality claims beyond what the gate proved.
- Never show a result the shipped pipeline did not produce (fixtures in `app/test/fixtures/photos/expected/` are the approved source).

### 10.5 Launch platforms, order, localisation

- **Platform order (decided, §15 D8):** Google Play first (Android-only MVP). iOS is Phase 2 (§2.3). Code iOS-clean from day 1.
- **Play launch mechanics (Verified, `research/platform-requirements.md`):** target API 36 from the first build; new personal developer accounts need **12 testers opted in continuously for 14 days** in a closed test before production — **tester recruitment starts during development, not after it.**
- **Localisation at launch:** app UI in English; **store listings localised** for Tier 1 (Indonesian, Brazilian Portuguese at minimum; Spanish (LatAm) fast-follow). UI localisation follows in Phase 3 with Tier 2 markets.

---

## 11. Privacy and platform compliance checklist

All items are **CMP** requirements — a release is blocked until every applicable box is implemented and evidenced in `docs/compliance/`.

- **CMP-01 Picker-only photos.** System pickers only; no `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO`, no broad iOS library access (FR-01). Satisfies Play's Photo & Video Permissions policy (fully enforced 2025-05-28 — Verified) and Apple 5.1.1(iii) data minimisation.
- **CMP-02 Target/build gates.** Play: target API **36**, Billing Library **8+** (via RevenueCat SDK — confirm its bundled version at build time), 16 KB page-size support. Apple (Phase 2): Xcode 26 / iOS 26 SDK, deployment target iOS 15.
- **CMP-03 First-upload consent (Apple 5.1.2(i) + Play disclosure).** The S2 sheet (§4.2) shows **before the first upload**, naming where the photo goes, with explicit accept. Consent is versioned (`consent_version` in config); any change of processor or data types bumps the version and re-shows the sheet. Provider display name comes from build config so the copy can never drift from the real vendor.
- **CMP-04 Store data declarations (cloud design — declare, do not argue "transient").** Play Data Safety: Photos = **Collected**, purpose **App Functionality**, encrypted in transit = Yes, deletion available = Yes; Diagnostics (first-party job telemetry, §12) = Collected, App Functionality/Analytics as the form requires at submission. Apple App Privacy (Phase 2): User Content → Photos or Videos (App Functionality); Diagnostics. Exact answers live in `docs/compliance/store-forms.md` and must be updated in the same change as any data-behaviour change.
- **CMP-05 Retention & deletion implemented as code** per §7.4 (TTL jobs + deletion logging), processing buckets excluded from long-cycle backups.
- **CMP-06 Report this result (Play AI-content policy).** S7 carries a report control usable **without leaving the app**; submissions land in `reports` (§7.2). The result screen also carries the persistent disclosure line (§4.2 S7).
- **CMP-07 No-training commitment (publish verbatim in privacy policy + listings + consent copy):** *"Your photos are never used to train, fine-tune, or improve AI models — ours or anyone else's."* Make it true: our own worker runs open models on our infrastructure (no vendor training surface); any future vendor (e.g. Clipdrop fallback) requires a written no-training/commercial-terms confirmation **before** carrying traffic (§6.5), recorded in `docs/compliance/record-of-processing.md`.
- **CMP-08 Third parties in photos.** The app never identifies, names, or biometrically processes any person (detection = anonymous instance masks only). EXIF/GPS stripped on save (FR-15) and never read from uploads for any feature.
- **CMP-09 Data rights.** Settings → Delete my data (FR-24) + a privacy-policy URL live before submission (Play requirement) + the GDPR-standard posture run globally (one standard everywhere: access/deletion via the in-app endpoint, no per-region forks).
- **CMP-10 Watermark/logo ban.** No feature, keyword, screenshot, or copy may market watermark or logo removal (Apple 5.2 / Play IP + deceptive-behaviour exposure). Run the metadata lint (`tools/metadata_lint.md`) over all listing text before every submission.
- **CMP-11 Subscriptions hygiene.** Paywall shows price, billing period, renewal and cancellation path in plain language before purchase (Play subscription rules + Apple 3.1.2 pattern); Manage subscription deep-links to the store page (S10); no trial is offered at launch (§9.2), so no trial-terms surface exists to get wrong.
- **CMP-12 No ads, no accounts, no ATT.** No ads SDK, no AD_ID declaration, no tracking — App Tracking Transparency is not applicable and the privacy labels must stay that way (adding any tracker later requires an ADR + form updates in the same change).
- **CMP-13 Closed-test gate (Play).** 12 testers × 14 days continuous closed test completed before production submission for new personal accounts; start recruitment during Phase 1 of the build (§14).
- **CMP-14 Human-only steps.** Store account creation, legal enrolments (Small Business Program, Paid Apps agreement), entering secrets, age-rating questionnaires, and pressing Submit are developer actions — the agent prepares everything up to those clicks as a checklist (§6.3).

### 11.2 Exact disclosure wording (lift verbatim; `[…]` = build-config values)

**A. Consent sheet (S2):**
> **Before your photo is uploaded**
> To remove people, PeopleGone sends the photo you choose to [PeopleGone's processing servers] over an encrypted connection. Only that one photo is sent — PeopleGone does not access the rest of your library.
> Your photo is used only to create your cleaned photo. It is **never used to train AI models** and is **deleted from our servers when processing finishes, and in all cases within 24 hours**.
> [Continue and upload my photo]  [Cancel]
> Full details: Privacy Policy

**B. Result-screen line (S7):** "Processed securely · Original deleted from server · Report this result"

**C. Store listings:** "Photos you choose are uploaded for AI processing and deleted from our servers within 24 hours. We never train AI on your photos."

---

## 12. Analytics and quality metrics

### 12.1 Decision

**No third-party analytics or crash SDK in v1** (§15 D14). Quality is measured from two first-party sources that already exist in the design: (1) the server `jobs` metadata (§7.2 — people counts, mask ratios, timings, GPU-seconds, retries, ghost-check, processor — **never image content**), and (2) a minimal first-party event log (event name, anonymous install ID, timestamp, app version — no photos, no EXIF, no free-text except the optional report note). Declared on the store forms as Diagnostics (CMP-04). Crash visibility in v1: Play Console Android vitals + server logs. Any later third-party tool needs an ADR + same-change store-form updates (CMP-12).

### 12.2 Events to record

`app_open` · `photo_picked` · `consent_shown` / `consent_accepted` / `consent_declined` · `upload_completed` (bytes, ms) · `analysis_completed` (people_count, ms) · `proposal_shown` · `person_toggled` (keep↔remove) · `remove_started` · `remove_completed` (total ms, gpu_seconds, retry_count, ghost_check_fired) · `remove_failed` (stage, typed reason) · `result_viewed` · `brush_fix_used` · `result_saved` (free_save | pro) · `paywall_shown` (trigger) · `purchase_started` / `purchase_completed` (sku) / `purchase_failed` · `restore_used` · `report_submitted` · `job_queued_offline`

### 12.3 Success and quality metrics (review weekly post-launch)

| Metric | Definition | Healthy threshold (decision targets) |
|---|---|---|
| Activation | installs → first completed removal | ≥ 40% (Estimate target) |
| **Save rate** | completed jobs → saved result (the production "would post" proxy) | ≥ 60% |
| Ghost rate | jobs where the second-pass check fired | ≤ 15% and falling after fixes |
| Retry rate | jobs needing the automatic retry | ≤ 20% |
| Keeper incidents | reports mentioning a damaged/removed subject | **0 tolerance** — any confirmed case is a P1 fix |
| Median job time | upload-complete → result, warm | ≤ 20 s (NFR-01) |
| Cost per saved photo | monthly GPU spend ÷ saves | ≤ $0.01 at the §8.1 ceiling |
| Store rating | Play, Tier 1 markets | ≥ 4.3★ (§1.5) |
| Paywall conversion | paywall_shown → purchase_completed | track vs 2.1% download→paid planning median |

---

## 13. Testing and acceptance criteria

### 13.1 Standing rules

- Every task's done-definition includes: `flutter analyze` clean, `flutter test` green, new tests for the behaviour added (NFR-05).
- Compliance-named tests are mandatory and named after the rule they protect, e.g. `consent_gate_blocks_upload_before_consent_test.dart`, `paywall_never_before_first_result_test.dart`, `no_media_permission_in_manifest_test.dart` (asserts the merged manifest contains no media permission), `ledger_decrement_only_on_save_test.dart`.
- Server tests: ledger atomicity (concurrent saves can't double-spend), idempotent job creation, TTL deletion jobs actually delete (including failed-job files at 24 h), webhook refund revokes entitlement.

### 13.2 Acceptance criteria per requirement group

| Requirements | Acceptance test (summary) |
|---|---|
| FR-01, CMP-01 | Fresh install on Android 14+ and a minSdk-24 device: picking a photo shows the system picker; no permission dialog ever appears; merged manifest has no media permission. |
| FR-02, CMP-03 | First upload attempt is blocked until consent; declining → no network call to `/jobs` (verified in test with a mock server). Changing `consent_version` re-shows the sheet. |
| FR-03…FR-06 | Fixture set (§13.3): every person is instanced on the proposal; keeper is never in the default REMOVE set on any fixture; 0-person and subject-only fixtures produce the plain messages and consume nothing. |
| FR-07…FR-12 | Crowd/overlap/shadow fixtures process end-to-end; per-person undo restores exactly that person; a disliked re-run consumes no save (ledger unchanged). |
| FR-13…FR-18 | Save a 24 MP fixture: output dimensions identical; pixel-diff outside masks = 0 (before final encode); GPS EXIF absent, ICC present; original file's hash unchanged; history shows the entry after app restart. |
| FR-19…FR-22 | Reinstall + Restore returns Pro without support; free balance survives app restart (server-read); clearing app data does not reset the server ledger for the same store account/install identity beyond the documented anonymous-auth limits (known residual risk, §15 R7). |
| §7.4 / CMP-05 | A failed job's files are gone from both buckets at 24 h (test with shortened TTL in dev); a delivered job's original is gone at delivery. |
| §8.2 | Simulated 21st job in an hour is velocity-capped; circuit-breaker flags flip free processing to queue-only at the configured spend in a staging config. |
| §9 / S8 | Paywall cannot be triggered before a first result exists; with 0 saves the Save tap shows S8 with all three prices + terms visible without scrolling on a small-screen device; paying inside 24 h saves the held result without reprocessing (job log shows one processing run). |
| NFR-01/02 | On a mid-range Android over throttled 4G: warm median job ≤ 20 s across the fixture set. |

### 13.3 The fixed test-photo set (quality regression)

The Phase 0 frozen 30-photo set (§3.2) **is** the regression set. It lives in `app/test/fixtures/photos/` with a `FIXTURES.md` recording the consent/licence basis of every image (an image whose basis can't be written down does not enter the repo — never real user photos, never scraped images, never photos of children). `photos/expected/` holds developer-approved reference outputs from the shipped pipeline. Rules: (a) any pipeline/model/config change re-runs the whole set and the outputs are eyeball-compared + scored with the §3.3 rubric before merge; (b) a regression on any keeper-damage case blocks release; (c) canned server responses (success/failure/timeout) live in `test/fixtures/server/` so UI tests never touch the network; (d) an integration test covers the golden path end-to-end against the mock server: pick → consent → proposal → remove → save → history.

---

## 14. Build plan (execute in this order; each task has a done-definition)

### Phase 0 — Quality gate (no app yet) — §3
- **0.1 Worker prototype:** containerised pipeline (§6.4) callable as `process(photo, keep) → result + metadata`, running on RunPod Serverless. *Done when:* it processes a 24 MP photo end-to-end and returns a native-res result + GPU-second log.
- **0.2 Model licence pack:** licences for detector checkpoint, SAM 2.1, big-lama archived in `docs/licences/`; YOLO excluded. *Done when:* every shipped weight has a licence file + a one-line commercial-use note.
- **0.3 Test set + harness:** 30 photos frozen with ground truth (§3.2); batch runner + blind-review page built; Clipdrop arm wired (free dev credits). *Done when:* a dry run produces blinded A/B pairs for all 30.
- **0.4 Blind test + decision:** 5–10 raters score per §3.3; apply the §3.4 rule **as written**. *Done when:* a signed decision note (GO / ITERATE-with-named-swap / STOP) is in `docs/architecture/`. **If STOP: the project ends here and the finding is reported — do not proceed to Phase 1.**

### Phase 1 — App scaffold + mock golden path
- **1.1 Repo + pins:** create the §6.2 structure, `AGENTS.md` (§6.3), FVM pin, GetX scaffold, CI (analyze + test). *Done when:* CI green on an empty-feature build; `pubspec.lock` committed.
- **1.2 Picker + Home + History (local):** S1/S9 with `image_picker`, local history files + index. *Done when:* FR-01/FR-18 tests pass; no permission dialog on any test device.
- **1.3 Mock processing end-to-end:** mock server returning fixture proposals/results; S3–S7 wired incl. compare, brush UI (mask editing local), save-to-history. *Done when:* the §13.3(d) integration test passes against the mock.
- **1.4 Closed-test recruitment starts (human):** developer recruits the 12 Play closed-test testers now (CMP-13) so the 14-day clock can start the moment a real build exists.

### Phase 2 — Real backend + processing
- **2.1 Supabase gateway:** schema (§7.2), anonymous auth, Edge Functions (§7.3), private buckets + signed URLs. *Done when:* API contract tests pass; no key exists in the client build (verified by APK scan in CI).
- **2.2 Worker deployment:** RunPod endpoint (scale-to-zero), gateway→worker job flow, idempotency, second-pass check + retry. *Done when:* NFR-01/02 measured on the fixture set over throttled 4G; cost per job logged ≤ $0.01.
- **2.3 Consent gate + retention jobs:** S2 with versioned consent + records; TTL deletion jobs + deletion logging live. *Done when:* CMP-03/CMP-05 tests pass (§13.2).
- **2.4 Real-device ASO check (human + agent):** in-store rank for the primary phrases on real devices US/GB + free-trial ASO pull (§10.2). *Done when:* results recorded; any phrase demotion is an ADR.

### Phase 3 — Money
- **3.1 RevenueCat + paywall:** SKUs (§9.2) in Play Console (human creates products; agent prepares the checklist), `PurchaseService`, S8 per §9.3, restore, webhook → ledger. *Done when:* sandbox purchase/renew/refund/restore all verified; §13.2 paywall tests pass; Small Business Program enrolment done by the developer **before** submission.
- **3.2 Cost protection live:** velocity caps, fair-use cap + 80% warning, result cache, circuit breakers (§8.2) as gateway config. *Done when:* §13.2 abuse tests pass.

### Phase 4 — Compliance + launch (Android)
- **4.1 Compliance pack:** privacy policy published (from `docs/compliance/privacy-policy.md`), store-forms.md completed, report flow (FR-23), Delete-my-data (FR-24), metadata lint over all listing text (CMP-10). *Done when:* every CMP item has evidence linked in `docs/compliance/`.
- **4.2 Store assets:** screenshots + preview video from real outputs (§10.4), localised listings (§10.5). *Done when:* assets match shipped-pipeline outputs in `fixtures/expected/`.
- **4.3 Closed test → production:** closed track build, 12 testers × 14 days, fix P1s, production submission (human presses Submit, CMP-14). *Done when:* the app is live on Play in Tier 1 markets; RunPod idle-ping schedule (§6.4) is active; §12 weekly metrics review is calendared.

### Phase 5 — iOS fast-follow (after the §2.3 trigger)
- **5.1** iOS build green (iOS 15 target), StoreKit via the same `PurchaseService`/RevenueCat, App Privacy labels from store-forms.md, 5.1.2(i) consent verified in the iOS build, App Store assets. *Done when:* live on the App Store with the §10.1 subtitle/keyword field.

---

## 15. Decisions Log, Facts vs Assumptions, Risks

### 15.1 Decisions Log — every specialist conflict, resolved (no either/ors remain)

| # | Conflict | Decision | Reason |
|---|---|---|---|
| D1 | **Processing engine:** Technical (own LaMa pipeline on serverless GPU) vs Costs §5.4 ("prefer hosted cheap API (fal SDXL) for v1 speed below ~40–80k photos/mo") | **Own pipeline on RunPod Serverless (Technical).** Gateway keeps the processor swappable (§6.5 routing flag). | Detection, masks, keep-logic, and compositing must be built anyway — the API only rents the cheapest step. SDXL is diffusion: hallucinated-people risk + no instance keep-control. LaMa is cheaper per photo and deterministic. Costs' underlying concern (don't buy ops burden early) is met by serverless scale-to-zero + the portable container. Phase 0 (§3) is the arbiter if quality disagrees. |
| D2 | **Per-photo cost figure:** Technical $0.002–0.006 vs Costs ~$0.0010 | **Budget at the $0.006 ceiling** everywhere in §8. | Costs' figure is the warm best case; Technical's includes cold starts, idle waste, retries. Planning on the ceiling keeps the free tier safe under the worst case. |
| D3 | **Backend shape:** Costs (Supabase gateway + server ledger + anonymous auth) vs Platform ("no accounts") vs Technical ("thin backend") | **Supabase minimal backend, anonymous auth, no user accounts** (§7). | All three actually agree once "account" means *user-facing* account: the ledger and key protection force a backend; anonymous auth gives identity without an account wall or deletion machinery. |
| D4 | **Billing SDK:** Platform pin (`in_app_purchase` behind `PurchaseService`) vs Costs (RevenueCat) | **RevenueCat behind `PurchaseService`** (§6.1). | Solo dev + Phase 2 iOS parity + restore/webhook handling outweigh the extra disclosed processor (listed in CMP-04) and the ~1% fee above $2,500 MTR (free below it). The interface keeps the swap reversible. |
| D5 | **One-time price:** mission research ($9.99) vs Costs ($34.99 Lifetime + $19.99/yr + $4.99/mo) | **Costs wins** (§9.2). $9.99 survives only as a possible future time-boxed promo — not an MVP SKU. | A $9.99 lifetime beside a $19.99/yr plan makes the annual irrational and maximises lifetime GPU liability (cannibalisation arithmetic, Costs §3.4). |
| D6 | **"No monthly cap" claim:** ASO draft screenshot claim vs Costs (10 free saves/mo) + UF-08/UF-11 (honesty rules) | **ASO claim rejected.** The free limit is real and stated plainly in the listing and screenshots (§10.3/§10.4). | A "no cap" claim next to a 10/mo cap would be exactly the shelf's hated deception pattern — and false. |
| D7 | **Gate design:** mission rule (20 photos, comparable ≥7/10) vs Technical (30 photos, multi-threshold) | **Technical's 30-photo set + thresholds** (§3.2/§3.4), extended with UF-20/UF-21 cases (fine-edge, low-light). | It operationalises the mission rule measurably (its ≥70% "would post" ≈ the 7/10 bar) and adds the keeper-damage zero-tolerance the mission implied but never quantified. |
| D8 | **Platform order:** ASO (Android-weighted tiers) + Platform (Android-only MVP) vs mission's "Android-first, older iPhones second" | **Android-only MVP; iOS Phase 2** with iOS-clean code from day 1 (§2.3, §10.5). | Both specialists converge; "older iPhones second" is satisfied by Phase 2's iOS 15 floor keeping iPhone 8/X. |
| D9 | **Shadow/reflection scope:** Competitors (headline feature: shadows *and reflections* removed together) + UF-03 (mask includes both by default) vs Technical (shadows = heuristic; reflections = warn-only v1) | **Shadows: automatic, default ON (§6.4). Reflections: brush-mode + warn in v1; automatic reflection removal is NOT promised** (§5 FR-09). | No engine in the research solves reflections automatically; promising it would break the honesty rules. Shadow expansion is buildable now; reflections get the manual rescue path users already accept (UF-15). |
| D10 | **EXIF handling:** Competitors ("preserve EXIF") vs Platform/Technical (strip GPS) vs UF-07 (disclose) | **Preserve orientation + ICC + non-location EXIF; always strip GPS; disclose on the save screen** (FR-15). | Satisfies photographers (colour/orientation), privacy law sense (location), and the disclosure requirement simultaneously. |
| D11 | **Free-tier mechanics:** Costs (credit spent on save; previews free) vs UF-11 (free tier must let users judge real quality at full res) | **Both:** processing + on-screen preview unlimited and uncounted; the **save** consumes the allowance; the 10 free saves are genuinely full-res and watermark-free (§9.1). | Users judge real quality before paying (UF-11) while the meter sits on the deliverable, mirroring Google's own "save" counting — and §8.2 velocity caps bound preview-processing abuse. |
| D12 | **On-device role:** Technical (not the v1 engine; preview/triage only) vs UF-19 (prefer on-device — Should) | **No on-device ML in v1** — not even triage. Cloud-only, with the CMP-03 consent + CMP-07 no-training disclosure carrying the privacy story. Revisit in Phase 3. | One pipeline is what Phase 0 can validate; ML Kit segmentation targets foreground subjects (the people we *keep*), merges touching people, and is Android-only/beta. Splitting v1 across two engines doubles the quality surface a solo dev must gate. UF-19's Must half (disclosure) is fully implemented; its Should half (on-device) is deferred with this reasoning. |
| D13 | **State management:** Platform memo left it open (noted GetX house style as an Assumption) | **GetX, pinned** (§6.1). | It is the developer's established style in the Darzi project (Verified from project history); one pattern everywhere is what keeps agent-built Flutter maintainable. |
| D14 | **Analytics:** Platform pin ("none in v1") vs the need to measure production quality (§12) | **First-party minimal telemetry YES; third-party SDKs NO** (§12.1). | The ghost/retry/save-rate metrics are the production form of the Phase 0 gate — flying blind is worse. First-party job metadata adds no new data collector to the store forms beyond Diagnostics. |

### 15.2 Facts vs Assumptions register (key items)

**Verified (source, 2026-10-12):** exact phrase `remove people from photo` iOS #1 has 1 rating (iTunes Search API) · TouchRetouch 58,146 US iOS ratings at 4.74★ (iTunes API) · Apple Clean Up needs iPhone 15 Pro+ · Google Magic Editor 10 free saves/mo for non-Pixel/non-Premium · Cleanup.pictures free 720px cap, Pro $5/mo / $36/yr · SnapEdit ~21M downloads / 4.46★ Android, free tier 1,600px + watermark + ads · SAM 2 checkpoints Apache 2.0 · Ultralytics YOLO AGPL-3.0/Enterprise · Clipdrop Cleanup: mask-based, 1 credit/call, 60 req/min, 16 MP cap, no public per-credit price · Stability output cap ~9.4 MP · RunPod Serverless 16 GB tier $0.00016/s, 7-day idle max-workers trap · Play target API 36 from 2026-08-31, 12-tester × 14-day closed test for new personal accounts, Photo & Video Permissions policy enforced 2025-05-28 · Apple Guideline 5.1.2(i) AI disclosure wording (2025-11-13) · RevenueCat free < $2,500 MTR then ~1%; freemium download→paid median 2.1%; Photo & Video trial→paid 22.2%; plan retention Annual 44.1% / Monthly 17.0% / Weekly 3.4% · store commissions 15% (small-business programs) · Fiverr/Upwork human removal $5–10/photo (Oct 2026 listings).

**Estimates (labelled assumptions shown in the memos):** primary pipeline $0.002–0.006/photo (budget ceiling $0.006) · warm job 5–15 s, cold 15–45 s · launch downloads 800–2,500/mo base case · blended ARPPU ~$22.24 gross · activation/save-rate targets in §12.3 · dedicated-GPU crossover ~50–65k photos/mo · Tier 1 Android shares 81–92%.

**Assumptions (decisions without direct evidence — change only via ADR):** keeper-heuristic weights (§6.4) · shadow-expansion heuristic behaviour · 100 MP / 60 MB input cap · free processing velocity cap of 20 jobs/day · 72 h offline entitlement grace · input-cap and fair-use numbers (300/mo) · Flutter/GetX/package pins as of project start (record exact versions in Task 1.1).

### 15.3 Risks register

| # | Risk | Severity | Mitigation in this doc |
|---|---|---|---|
| R1 | LaMa fill quality fails the gate on crowds/overlap (the product's core case is the hardest case — UF §2 Ranks 1–3) | Existential | Phase 0 before any app spend; ITERATE swaps pre-decided; STOP is an allowed, honoured outcome (§3.4). |
| R2 | SnapEdit ships a people-mode with subject protection first | High | Launch speed; own the exact phrase early; differentiate on full-res free saves + honest pricing, which it does not offer. |
| R3 | Platform-limit erosion (Apple extends Clean Up down-market; Google lifts the 10-save cap) | High, uncontrollable | Accepted — it is why speed matters and why pricing/quality must stand without the gap. Re-verify caps before launch (they are Oct 2026 facts). |
| R4 | Model-weight licence surprise (big-lama / detector checkpoint) | Medium | Blocking licence task in Phase 0 (§3.1); YOLO excluded; licences archived before release. |
| R5 | Clipdrop fallback unusable (no written price / terms refused) | Medium | Fallback-of-fallback = queue on primary (§6.5); fallback is failover, not a launch dependency. |
| R6 | API/GPU cost abuse (farms, retry loops) | Medium | §8.2 controls are launch requirements, incl. circuit breakers and idempotency. |
| R7 | Anonymous-identity limits (reinstall/device change vs ledger/restore edge cases) | Low–Medium | Store-account-based restore via RevenueCat for paid entitlement; residual free-tier reset risk accepted and capped by velocity rules + attestation slow-queue. |
| R8 | Cold-start latency on serverless GPU hurts first-job experience | Medium | FlashBoot on; proposal-first UX (Stage A feels fast); honest progress states (S6); measure NFR-01 in Phase 2. |
| R9 | Apple Guideline 4.3 (spam) rejection in Phase 2 on a crowded shelf | Medium | Phase 2 only after Android traction exists as evidence of a distinct, working product; iOS-clean code keeps the attempt cheap. |
| R10 | Pricing A/B chaos later destroys the "honest price" claim | Low | §9.3 grandfathering is a hard rule; prices are config, and any change is new-buyer-only. |
| R11 | True in-store rank for the primary phrase differs from web-indexed research | Low | Mandatory real-device check + ASO trial pull before submission (§10.2); demotion rule pre-written. |

---

*End of requirements. This document, the six memos in `research/`, and the mission evidence in `~/workspace/tentacle-app-discovery/` together are the complete pre-development record for PeopleGone.*
