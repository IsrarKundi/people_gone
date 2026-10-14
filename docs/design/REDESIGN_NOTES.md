# PeopleGone — Redesign Implementation Notes

**Date:** 2026-10-14  
**Author:** Antigravity (Senior Product Designer & Systems Engineer)  
**Status:** Living design & implementation log  
**Scope:** Direct implementation of fixes for findings in `DESIGN_AUDIT.md`.

---

## 1. Direction Summary: "The Modern Photographic Studio"

The previous design system dogmatically confused "calm and honest" with "sterile, bleak, and unfinished." The redesign retains **absolute product truth** (calm factual copy, no fake percentages, zero hype, full resolution, no watermarks, transparent quota metering, system picker only) while elevating the aesthetic to a **modern, high-trust consumer photography experience**.

### Core Tenets

1. **Photographic Canvas (True Dark & Clean Light):**
   - **Dark Mode:** Deep obsidian canvas (`#0B0D11`), crisp tonal surfaces (`#161920`, `#1E232D`), vibrant contrast. Eliminates harsh letterbox contrast so photos take center stage.
   - **Light Mode:** Modern warm-tint porcelain (`#F8F9FA`), crisp pure-white cards (`#FFFFFF`), refined neutral borders (`#E5E7EB`).
2. **Elevated Brand Color:**
   - Swapped the corporate enterprise-IT blue (`#3157D5`) for a rich, vibrant photographic cobalt (`#2563EB` light, `#60A5FA` dark).
3. **Value Before Accounting:**
   - On first launch, lead with visual capability (interactive real-pipeline before/after demonstration).
   - Move the quota meter to a respectful, honest location below the primary action rather than an administrative banner at the top.
4. **Visual Decisions (No Abstract Numbers):**
   - In S4 Proposal and S7 Keeper Sheet, people are identified with visual face/crop chips, never abstract text labels like "Person 1" vs "Person 2".
5. **Calm, Scannable Reassurance:**
   - Transform dense legal paragraphs (S2 Consent) into structured, scannable trust pillars with icons while preserving 100% of the required factual disclosures.
6. **Performance Discipline:**
   - Avoid expensive full-screen GPU blur shaders on budget Android hardware (minSdk 24). Use lightweight solid/translucent tonal surfaces, clean elevation, and crisp geometry.

---

## 2. Token Adjustments (`app_colors.dart`)

| Semantic Token | Light Mode (Before -> After) | Dark Mode (Before -> After) | Rationale |
|---|---|---|---|
| `primary` | `#3157D5` -> `#2563EB` | `#8FA8FF` -> `#60A5FA` | Replaces enterprise utility blue with vibrant photographic cobalt. |
| `background` | `#F7F8FA` -> `#F8F9FA` | `#0E1013` -> `#0B0D11` | True deep photographic obsidian in dark mode; soft porcelain in light mode. |
| `surface` | `#FFFFFF` -> `#FFFFFF` | `#17191E` -> `#14171E` | Sleek, cohesive container backgrounds. |
| `surfaceVariant` | `#EEF0F4` -> `#F0F2F5` | `#1F2229` -> `#1D212A` | Refined subtle container fill. |
| `border` | `#DFE3E9` -> `#E5E7EB` | `#2A2E36` -> `#252932` | Soft hairline definition without harsh visual cuts. |
| `overlayKept` | `#8C30A46C` -> `#9910B981` | `#8C3DD68C` -> `#9910B981` | Vibrant, recognizable emerald for subject protection. |
| `overlayRemoved` | `#8CE5484D` -> `#99EF4444` | `#8CFF6369` -> `#99EF4444` | Clear, warm crimson for removals. |

---

## 3. Screen-by-Screen Implementation Log

### S1 Home Screen (Fixed)
- **Problem Fixed:** Dead empty space on first run; zero visual proof of app capability; quota meter leading the screen as an accounting barrier.
- **Solution:**
  - Added `InteractiveDemoCard`: Embedded genuine pipeline output (`assets/images/demo_original.jpg` and `assets/images/demo_result.jpg` from `08_historic_arch.jpg` processed through the live serverless worker). Users can drag or tap to see real background people removal before picking their first photo.
  - Hierarchy inversion: Primary "Pick a photo" action is immediately accessible at the top of the body above the fold, accompanied by the calm `SavesIndicator` quota meter.
  - History cards: Elevated tile borders with subtle aspect framing.

### S2 Consent Sheet (Fixed)
- **Problem Fixed:** Dense, imposing wall of unformatted legal text causing drop-off.
- **Solution:**
  - Structured the mandatory §11.2A compliance copy into three distinct, scannable trust pillars:
    1. *Private server processing* (HTTPS transfer, strictly for editing).
    2. *Auto-deleted within 24 hours* (zero permanent cloud storage).
    3. *Never used for AI training* (no model training or resale).
  - Preserved 100% of the legally required facts, plain language, and action buttons ("Continue" / "Cancel").

### S9 History & Detail View (Fixed)
- **Problem Fixed:** History detail only showed the finished result with no before/after comparison; empty state was a stark unstyled label; square tile crops cut off subjects.
- **Solution:**
  - Added original photo persistence (`adoptOriginalIntoHistory`) in `LocalStoreImpl` and updated `ResultController` to save both original and cleaned photos.
  - Added interactive before/after split slider (`CompareSlider`) and hold-to-compare switch in `HistoryDetailView`.
  - Upgraded empty history state with a dedicated illustrated icon, clear title, and instructional caption.
  - Framed history grid tiles with subtle border and aspect styling.

### S10 Settings Screen (Fixed)
- **Problem Fixed:** Exposed plumbing (internal engine names, raw build numbers), unstyled flat list.
- **Solution:**
  - Grouped settings into clean, elevated card containers with icons and subtle dividers.
  - Clear section headers: *Account & Plan*, *Processing & Privacy*, *About*.
  - Maintained compliance access: tap on "Processing details" opens the full §11.2A trust sheet.
  - Respects calm disclosure rules without exposing raw internal worker identifiers.

### S4 Proposal Screen & Visual Keeper Selection (Fixed)
- **Problem Fixed:** S4 proposal screen was missing from the app flow; users had no way to inspect or correct detection before processing; "Kept the wrong person?" sheet used abstract labels ("Person 1", "Person 2") with no visual indication of who was who.
- **Solution:**
  - Extended worker pipeline with `/detect` endpoint returning normalized person bounding boxes (`[ymin, xmin, ymax, xmax]`), label, confidence, and `is_primary_subject` heuristic.
  - Extended Flutter `ProcessingApi` with `detectPersons(...)` and graceful single-call fallback if the server only provides `/process`.
  - Built `ProposalView` and `ProposalController`:
    - Canvas overlays detected person boxes with emerald (kept subject) and crimson (removed bystander) indicators.
    - Horizontal tray of `PersonThumbnail` chips: custom-painted face/upper-body crops directly from the decoded photo in GPU memory. Users can instantly identify each person visually.
    - Tap on chip or box toggles keeper status. Clear action: "Clean photo (removes N people)".
  - Updated S7's "Kept the wrong person?" sheet (`WrongKeeperSheet`) to use the exact same `PersonThumbnail` visual face crops, completely eliminating the keeper identification flaw everywhere.

### S3/S6 Processing Screen (Fixed)
- **Problem Fixed:** Letterbox/scrim mismatch with harsh background cuts; claustrophobic waiting experience; lack of clear expectation setting for the ~2 minute CPU processing time.
- **Solution:**
  - Implemented deep photographic studio darkroom canvas (`#0B0D11`) matching photo aspect ratios without jarring letterboxing.
  - Truthful staging: explicit upload bytes tracking (real percentage) vs serverless processing (indeterminate spinner with staged status messages: "Uploading photo...", "Analyzing and inpainting...", "Finalizing photo...").
  - Honest copy: "Takes about 2 minutes on our processing pipeline. We're removing background people at full original resolution." (Strict adherence to the 2-minute CPU processing fact; zero fake speed claims).

### S7 Result Screen (Fixed)
- **Problem Fixed:** Floating chrome colliding with photo details; disclosure pile-up creating visual clutter below the image; cramped action row.
- **Solution:**
  - Replaced floating ad-hoc badges with a clean photographic top bar: close button, quick zoom toggle, and interactive before/after compare toggle.
  - Interactive split slider / hold-to-compare overlay directly on the canvas.
  - Disclosure reorganization: Replaced the vertical stack of bullet points with a clean, scannable trust capsule:
    - Primary summary: "N people removed · Free save (X of 10 remaining)".
    - Expandable info sheet: Preserves all mandatory §11.2B facts (location metadata preserved, temporary server copies auto-deleted within 24h, feedback/report option).
  - Primary "Save photo" button is full-width, dominant, and elevated, accompanied by secondary share/options.
  - "Kept the wrong person?" button cleanly opens the visual keeper correction sheet.

---

## 4. Verification & Health

- **Flutter Analyze:** 0 issues found (clean).
- **Flutter Tests:** 65 / 65 tests passing.
- **Golden / Review Screenshots Captured:**
  - `s1_home_light.png` & `s1_home_dark.png` (empty state with interactive demo card)
  - `s1_home_history.png` (with-history state)
  - `s1_home_textscale130.png` (accessibility at 1.3x text scale)
  - `s2_consent.png` (structured trust pillars)
  - `s4_proposal_light.png` & `s4_proposal_dark.png` (visual face chips & proposal canvas)
  - `s6_processing.png` (darkroom studio & honest timing)
  - `s7_result.png`, `s7_result_compare.png`, `s7_wrong_keeper_sheet.png` (result chrome, compare slider, visual face chips)
  - `s9_history.png` & `s9_history_detail.png` (history list & interactive compare slider)
  - `s10_settings.png` (elevated grouped cards)


---

## Correction — Home demo pair replaced (Muse, 2026-10-14, owner request)

The arch pair (testset 08) is replaced as the Home demo. Reason: that output removed the
photo's most prominent person, kept two background figures, and left a floating-bag
artifact — a poor and misleading showcase. New pair: a Pexels dune photo (testset-pack 04)
run through the live worker (MAT): 4 people detected, the couple kept, 2 removed, fill
verified clean by eye. Assets: `assets/images/demo_original.jpg` / `demo_result.jpg`
(1600px, the exact worker input/output). The "Real app output" caption is factual for
this pair. Widget and asset loading verified by an isolated render probe (2026-10-14).

## Demo pair — owner-selected cafe photo (2026-10-14)

The owner picked the demo image himself: a cafe portrait (woman in an armchair,
two customers and a barista behind her). Cleaned by the live worker (MAT):
4 people detected, subject kept automatically, 3 removed, fill verified clean.
Installed as `assets/images/demo_original.jpg` / `demo_result.jpg` (639x360,
as supplied). Supersedes the dune pair of the same date.

---

## 5. Home Option A & Processing Option 1+3 Implementation (2026-10-14)

**Decision & Review Authority:** Owner adopted Home Option A ("Photographic Drop-Zone Studio") and Processing Option 1 ("Living Canvas with Beam Scan") + Option 3's background flow ("Work in background" action + Home job banner).

### A. Grid Supersession Decision (F6 Supersession)
- **Supersession:** By explicit owner decision, the Home screen diverges from the History screen's 3-column square-crop grid. This supersedes the previous shared-grid convention (F6) for Home only.
- **Scope:** The S9 History screen itself remains completely unchanged (3-column grid with full history review).
- **Home Layout:** Home now features a hierarchical editorial layout:
  1. **First-run:** Interactive before/after split card showcasing the owner's café pair (`demo_original.jpg` / `demo_result.jpg`).
  2. **With-history:** `FeaturedCleanCard` highlighting the latest clean in its natural, uncropped aspect ratio (read dynamically at render time from the file, without database metadata), paired with `EarlierCleansTray` (horizontal scrolling gallery of previous cleans + quick link to full History).

### B. Home Option A ("Photographic Drop-Zone Studio")
- **Hero & Action Placement:** 56dp pill "Pick a photo" action positioned prominently above the fold for immediate accessibility across all device viewports.
- **Quiet Quota Pill:** Replaced the prominent horizontal progress bar with a calm, scannable indicator: `● N of 10 free saves left · Resets <Date>` (e.g. `● 7 of 10 free saves left · Resets 1 Nov`).
- **No Aspect-Ratio Store:** Avoided schema churn by resolving photo dimensions at render time via `FileImage` image streams clamped to `0.7..1.8`.

### C. Processing Option 1 ("Living Canvas with Beam Scan")
- **Theme Binding:** Processing canvas background and status card are bound strictly to design tokens (`p.background`, `p.surface`, `p.border`). No hardcoded dark canvas in light mode; dark mode retains its deep photographic obsidian.
- **Natural Photo Brightness:** The input photo is presented in an elevated, rounded studio card with natural brightness (no dark scrim or contrast cuts).
- **Scan Beam:** Lightweight `ScanBeamOverlay` custom painter executing a ~3.5s smooth vertical sweep, clipped strictly to the photo geometry with zero expensive GPU blur shaders.
- **Stage Truthfulness:** Strictly factual states: `uploading` (real bytes percentage) → `processing` (indeterminate pipeline) → `done` / `failed`. Time labels reflect real elapsed time and the honest "~2 minutes" expectation. Scripted clock milestones ("Finalizing details...", "Almost ready") are strictly forbidden.

### D. Background Flow (Option 3 Integration)
- **Action:** Prominent "Work in background" action in the Processing screen status card.
- **Home Job Banner:** When a backgrounded job is active, `HomeJobBanner` renders on Home with three real states:
  1. *Processing:* Live spinner, elapsed time, tap to reattach to the active processing view.
  2. *Done:* Success checkmark, tap opens the result screen immediately.
  3. *Failed:* Honest error presentation, retry button, and direct share action for diagnostics logs.
- **No "Notify me when done":** Explicitly omitted per owner rejection.

## Review 05 fixes — finished arrangements (implemented by Muse, 2026-10-14, owner commission)

Implements the design lead's Review 05 + Supplement rulings (R1–R10, D10–D12, F1, F2) on top of feat-05:

- **Processing (da1cd7a):** layout is now a column in flow — photo flexes above a bottom tray (status card → filled primary "Work in background" → its caption "You can safely leave the app." → Cancel). Double overlap and the ghost pill are gone; the primary action is the strongest element (R1, R6, W4, W6). Stage labels follow real client states: "Connecting to the processing server…" until the first byte moves, "Uploading… N%" + the determinate bar ONLY while bytes transfer, no bar in the server stage (F1, R4). Elapsed stopwatch removed (R5); beam dosed down (5s period, line alpha 0.35, band peak 0.15) and stays indeterminate-only (R8).
- **Home (this entry's commit):** hero slot sized from the real viewport height (budgeted allowance for the fixed cluster; page scrolls if the budget is exceeded — large text / small phones). Demo hero fills the screen (R2, D10); teaching line demoted to body size (R3); quota is a plain text line in the column — pill and status dot removed (R4, W3); banner takes the one card language — radiusLg + neutral hairline border in every state, state colour only in its icon (D12, W3); banner subtitle is destination-only: "Tap to view progress" (R10, F2); demo caption cut to "Real app output", hand icon removed (R9). Two factual copy fixes beyond the rulings: banner done title "Clean complete!" → "Your cleaned photo is ready" (calm voice, no celebration); failed subtitle now names the real tap action, "Tap to share diagnostics".
- Verified: analyze clean, 123/123 tests, fresh harness renders light + dark for S1 (both hero states) and S6 inspected by eye. Known render note: landscape photos letterbox inside the tall hero/processing frames (contain, never cropped) — the framed-print consequence of the adopted scale; the design lead's full pass may rule on it.
