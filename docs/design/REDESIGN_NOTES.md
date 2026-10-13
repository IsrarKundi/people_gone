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

## 3. Screen-by-Screen Progress Log

- **S1 Home:** (In progress) Adding interactive Before/After demo card with real pipeline output; relocating quota meter below action; updating layout rhythm.
- **S2 Consent:** (In progress) Structuring §11.2A text into 3 scannable trust points with icons.
- **S4 Proposal:** (In progress) Worker API `/detect` + client controller + face crop chips for keeper selection.
- **S3/S6 Processing:** (In progress) Unifying photo surround, adding staged progress cues and honest 2-minute expectation text.
- **S7 Result:** (In progress) Polishing top chrome, reorganizing disclosure layout, dominant Save button.
- **S9 History:** (In progress) Aspect ratio preservation on thumbnails, empty state illustration, Before/After comparison in detail view.
- **S10 Settings:** (In progress) Grouped settings cards, discrete processing disclosure without exposed plumbing.
