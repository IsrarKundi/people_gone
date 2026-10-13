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

### S4 Proposal Screen & Visual Keeper Selection (Next)
- Extending worker with `/detect` endpoint and person bounding boxes.
- Building proposal screen with face/crop avatars so users visually distinguish subjects from bystanders.

### S3/S6 Processing (Next)
- Harmonizing photo canvas background, staged progress cues, and honest ~2-minute copy.

### S7 Result Screen (Next)
- Streamlining top navigation bar, floating compare capsule, and reorganizing disclosures above a full-width Save button.

