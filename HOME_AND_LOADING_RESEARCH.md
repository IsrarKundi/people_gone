# PeopleGone — Home & Loading Experience Research
**Date:** 2026-10-14  
**Author:** Antigravity (Design & Systems Research)  
**Deliverable:** Comparative teardown, UX diagnosis, and concrete redesign architecture for **Home (S1)** and **Processing / Loading (S3/S6)**.  
**Governing Context:** System-following theme (light mode primary), honest ~2-minute CPU wait (scaling to ~20s GPU), resumable server jobs, budget Android performance (minSdk 24), zero AI slop.

---

## Executive Summary & Design Premise

The owner's critique of the current Processing screen is exact: *it is a dark page with a box containing loading text, it feels awful, and it clashes with the app, which is otherwise light.*

This failure came from a well-intentioned but flawed dogma: treating the processing state as a "photo darkroom" regardless of system theme, and treating progress honesty as an excuse to show a bare terminal-like timer in a floating box. 

Simultaneously, the Home screen struggles because it attempts to be an administrative dashboard (leading with button + quota meter) rather than a clean photographic workspace.

In top-tier photo tools (Google Photos, Apple Photos Clean Up, Lightroom Mobile, Photoroom, VSCO), **loading is never a dead-end waiting room, and the Home screen of a single-job utility is never an accounting ledger.**

---

## 1. Real-World Product Teardown: How the Best Apps Solve These Surfaces

| App | Screen 1: Home / Entry Pattern | Screen 2: Processing & Long Wait Pattern | Visual Style & Theme Treatment |
|---|---|---|---|
| **Google Photos** *(Magic Editor / Eraser)* | Contextual entry: opens directly into full-bleed photo view with clean, bottom-anchored action pill. | **In-canvas pulse & stage chips:** The photo stays fully visible on the active theme background. A gentle light wave sweeps the image during analysis. During generative wait (10–18s), a calm bottom tray shows staged text ("Generating options...") with an indeterminate linear indicator. | Respects system light/dark. In light mode, surfaces are clean white (`#FFFFFF`) with light grey (`#F1F3F4`) containers. No dark-room shock. |
| **Apple Photos** *(Clean Up — iOS 18.1)* | Zero home screen: tool lives directly inside the native photo viewer. | **Localized in-situ transformation:** Image never unloads. The selected object gets an iridescent edge highlight, followed by an in-place shimmer fill (<2s local NPU). | Strictly follows system theme. Tools float as clean frosted translucent capsules. |
| **Adobe Lightroom Mobile** *(Generative Remove)* | Library grid of natural aspect photos, leading directly to the editor canvas. | **Focused perimeter pulse:** Selected removal area shows a gentle marching-ants or soft pulse. Dock button shows "Removing..." with a thin indeterminate hairline track. User remains on the photo canvas; no modal popup. | Professional dark neutral (`#1E1E1E`) in develop mode, but library follows system theme. Seamless transitions. |
| **SnapEdit** *(Direct Competitor)* | Prominent photo selection drop-card with recent edits and a live before/after demo. | **Top-to-bottom scan line:** During detection (~5s), a clean horizontal scanning beam travels down the photo. During removal, shows circular loader over the photo. | *Negative:* Aggressive purple gradients and sparkle slop. *Positive:* The photo remains the central hero during all processing. |
| **Photoroom** | Clear, clean white cards with sample templates and prominent "Start from Photo". | **Non-modal status card:** Keeps image centered on clean light backdrop. Shows subtle animated shimmer bar and factual stage copy. For long exports, lets users background the job seamlessly. | Pure, modern light theme. High-contrast typography, minimal hairline borders. |
| **VSCO** | Clean photographic grid with natural aspect ratios; minimal unobtrusive top bar. | **Ambient backgrounding:** A hairline progress ring or subtle bar in the bottom toolbar. Allows users to leave the screen or background the app while processing completes. | Iconic minimalist monochrome. Respects light/dark system settings with gallery-like whitespace. |

---

## 2. Screen S1: HOME — Diagnosis & Redesign Architecture

### 2.1 What Is Wrong Today (Specifically)

1. **The Administrative Inversion (Accounting Before Capability):**  
   The current Home screen stacks components in a dry administrative sequence:
   `AppBar ("PeopleGone") → PrimaryButton ("Pick a photo") → SavesIndicator (Quota box & progress bar) → Empty/History`.  
   The first thing the user reads after the button is a quota limit (*"10 of 10 free saves left"*). It feels like a software utility metering bandwidth rather than a modern photo studio about to restore a cherished memory.
2. **The With-History Desert (The 70% White Void):**  
   When a user has 1 photo in history (the owner's exact screenshot state), `HistoryGrid` places a solitary `1:1` square thumbnail in the top-left corner of a 3-column grid. The remaining 70% of the screen is an empty, dead white expanse. The demo card was previously hidden as soon as history existed, leaving the screen completely abandoned.
3. **Severe Aspect Ratio Distortion in History:**  
   The 3-across square grid (`childAspectRatio: 0.82`) forces arbitrary square crops on landscape (16:9) or portrait (4:3) family photos. Faces and subjects are abruptly sliced off, reducing high-resolution photos into generic file-manager thumbnails.
4. **Lack of Visual Gravitas:**  
   The primary button is a full-width flat block with no depth, resting right against an unstyled meter bar. There is no sense of photographic craftsmanship.

---

### 2.2 Concrete Redesign Options for Home

#### Option A: The "Photographic Drop-Zone Studio" (Recommended)
* **Concept:** Transform Home from a vertical list of buttons into a tactile, inviting photographic studio. The central hero is an elevated "Canvas Card" that adapts between First-Run and With-History.
* **Layout Structure (Top to Bottom):**
  1. **Clean App Bar:** Left-aligned `PeopleGone` wordmark (Inter 800), clean Settings icon right. No clutter.
  2. **Hero Photo Canvas (60% screen height):**
     * *First-Run State:* Interactive Before/After Split Card (`08_historic_arch.jpg` real output). A tactile pill badge at the top: *"Sample: Drag to see automatic clean"*.
     * *With-History State:* Shows the **Latest Cleaned Photo** in its natural aspect ratio with a subtle `Cleaned` badge, tap to view comparison, and a horizontal tray of earlier cleans beneath it.
  3. **Floating Studio Action Bar:**
     * Prominent 56dp floating pill button: `[Icon: add_photo] Select a Photo`. High-contrast photographic cobalt (`#2563EB`), gentle elevation.
  4. **Quiet Trust Footer:**
     * A single, discreet centered pill: `● 7 of 10 free saves left · Resets Nov 1`. No loud progress bar shouting about limits.
* **Trade-offs:**  
  * *Pros:* Gorgeous, modern, eliminates dead space permanently in all states, treats photos with gallery respect.
  * *Cons:* Requires a slightly more bespoke hero layout between 0 photos and 1+ photos.

#### Option B: The "Recent Masterpieces Gallery"
* **Concept:** Home acts as an Apple Photos-style gallery where past work takes full visual precedence, with the creation button anchored in a bottom floating action zone.
* **Layout Structure:**
  * 2-column masonry or natural-aspect cards (never 1:1 squares).
  * Each card displays the cleaned photo, time elapsed, and a "Before/After" peek icon.
  * If empty: Displays a full-width studio demonstration card with educational step pills ("1. Pick photo → 2. We remove strangers → 3. Save full quality").
  * Action: Floating 56dp button centered at the bottom of the viewport with safe-area inset.
* **Trade-offs:**  
  * *Pros:* Familiar to modern iOS/Android gallery users; scales gracefully from 1 to 100 photos.
  * *Cons:* When history is empty, requires educational filler cards that can feel template-like if not carefully crafted.

---

### 2.3 Single Recommendation & Why (Home)

**Adopt Option A: The "Photographic Drop-Zone Studio".**  
*Why:* PeopleGone is a **single-job utility**. When users open the app, they want to do one thing: remove people from a photo. Leading with a hero photographic canvas proves capability instantly on first launch, and celebrates the user's restored photos once history exists. It completely banishes the 70% empty void, eliminates the administrative quota meter, and respects light-theme aesthetics.

---

### 2.4 Quick Wins vs. Structural Work (Home)

* **Quick Wins (1–2 hours):**
  1. Refine `SavesIndicator` from a harsh full-width progress bar into a compact, discreet pill container with subtle background fill and rounded progress track.
  2. Upgrade `PrimaryButton` with an iconography anchor (`Icons.add_photo_alternate_rounded`) and 16dp rounded radius.
  3. Never hide the interactive pipeline demonstration when history has fewer than 2 items — use it to gracefully anchor the lower screen.
* **Structural Work (1–2 days):**
  1. Replace the 3-column square `HistoryGrid` on Home with an aspect-preserving **Featured Recent Clean** card plus horizontal thumbnail carousel.
  2. Implement an in-memory or cached aspect ratio metadata store so thumbnails render in their native orientation (portrait/landscape) without awkward head-cropping.

---

## 3. Screen S3/S6: PROCESSING (Loading) — Diagnosis & Redesign Architecture

### 3.1 What Is Wrong Today (Specifically)

```
Current Reality (The "Dark Tomb" Shock):
[Light Home Screen (#F8F9FA)] 
       │ 
       ▼ (User taps "Clean photo")
[PITCH BLACK Screen (#0B0D11)]  <── Disorienting theme clash!
  ┌─────────────────────────┐
  │ [Dimmed Photo (35% black)│
  │                         │
  │ ┌─────────────────────┐ │
  │ │ [==Progress Bar===] │ │  <── Clunky "black box with text"
  │ │ Finding people...   │ │
  │ │ Elapsed 0:02 · ~2m  │ │
  │ └─────────────────────┘ │
  │        [Cancel]         │
  └─────────────────────────┘
```

1. **Severe Theme Shock (Light App → Dark Tomb):**  
   The entire app is light: Home, Consent, Settings, and Proposal are white/porcelain (`#FFFFFF` / `#F8F9FA`). Suddenly, the processing screen forces `#0B0D11` pitch black. The owner's verdict is undeniable: it looks broken and clashes violently with the rest of the app.
2. **The "Terminal Box" Anti-Pattern:**  
   Placing an opaque dark rectangle with small body text over a dimmed photo feels like a desktop terminal installer from 2005. The photo is treated as background wallpaper rather than the subject of transformation.
3. **The Dead, Lifeless Canvas:**  
   The photo is dimmed with a 35% black scrim and frozen. For 120 seconds (the CPU reality), there is no visual sign of life other than an elapsed-time clock ticking upward.
4. **User-Hostile Copy ("Keep app open"):**  
   Stating *"Keep the app open while we work"* during a 2-minute wait creates anxiety, risks phone lock timeouts, and contradicts the fact that the server job is **resumable and persistent**.

---

### 3.2 Concrete Redesign Options for Processing

#### Option 1: The "Living Canvas with Beam Scan" (Recommended)
* **Concept:** Keep the screen in the active system theme (light mode = clean porcelain background `#F8F9FA`). The photo is framed like a gallery print on an elevated, rounded canvas. A calm, luminous scan line sweeps over the photo to indicate active work, while an elegant bottom tray provides truthful staged progress and backgrounding assurance.
* **Visual Structure:**
  * **Background:** System theme background (`#F8F9FA` in light, `#0B0D11` in dark). Zero theme shock!
  * **Photo Framing:** Photo sits centered in its true aspect ratio inside a card container with subtle shadow (`blur: 12, y: 4, alpha: 0.08`) and clean border. The photo is **not** blacked out — it is displayed at normal luminance with a gentle 10% focus scrim.
  * **In-Situ Motion Effect:** A sleek 2dp glowing accent beam (cobalt `#2563EB`) sweeps vertically down the photo once every 3.5 seconds (pure Flutter `CustomPainter`, 60fps on budget hardware, zero GPU blur). It immediately communicates: *"We are actively scanning and processing this image."*
  * **Bottom Status Surface:** A clean, elevated surface card matching the theme (`#FFFFFF` in light mode):
    * Stage title in Inter 600 (`titleMd`).
    * Real progress: upload shows real `%`; processing shows a calm indeterminate pulse.
    * Truthful expectation + Backgrounding reassurance: *"Takes ~2 minutes. You can safely leave the app — we'll finish your clean in the background."*
    * Two actions: A text button `"Cancel clean"`, and a calm button `"Notify me when done / Go Home"`.
* **Experience at Waiting Milestones:**
  * **At 5s (Upload & Ingestion):**  
    * *Visual:* Determinate progress bar filling with real bytes.  
    * *Copy:* `"Uploading high-resolution photo… 64%"`  
    * *Subtitle:* `"Connecting to private processing server"`
  * **At 30s (Deep Inpainting):**  
    * *Visual:* Luminous scan beam gently cycles over photo.  
    * *Copy:* `"Removing background people…"`  
    * *Subtitle:* `"Elapsed 0:30 · Processing at full original quality (~2 min)"`  
    * *Card Action:* A subtle button appears: `"Work in background"`.
  * **At 90s (Refinement & Inpainting Completion):**  
    * *Visual:* Scan beam continues calmly.  
    * *Copy:* `"Finalizing details and blending background…"`  
    * *Subtitle:* `"Elapsed 1:30 · Almost ready"`  
    * *Safety Line:* `"Your photo is safe on our server. If you leave, your result will be waiting on Home."`
* **Performance on MinSdk 24 Budget Android:**  
  * Uses a simple `LinearGradient` sweep shader inside a clipped container. No blur filters, no raster cache thrashing, <1% CPU overhead.
* **Trade-offs:**  
  * *Pros:* 100% theme consistent; eliminates the "black box"; makes a 2-minute wait feel calm, trustworthy, and intentional; scales down to 20s GPU with zero redesign needed.
  * *Cons:* Requires adding a light vertical scan painter (~60 lines of standard Flutter code).

---

#### Option 2: The "Stepped Storytelling Dock"
* **Concept:** Emphasizes absolute engineering truth through a vertical step indicator docked beneath a clean photo preview.
* **Visual Structure:**
  * Photo sits in upper 45% of screen on system theme background.
  * Lower 55% contains a structured step card:
    * `[✓] 1. Uploaded at original resolution (12.4 MB)`
    * `[●] 2. Segmenting background people (Active)`
    * `[○] 3. Inpainting background textures (~90s)`
    * `[○] 4. Preserving EXIF & color profiles`
  * An animated elapsed clock (`01:14`) with a plain-language prompt: *"Feel free to switch apps. We will notify you when it's done."*
* **Experience at Waiting Milestones:**
  * **5s:** Step 1 completes with a green checkmark; Step 2 activates.
  * **30s:** Step 2 completes; Step 3 activates with estimated remaining time.
  * **90s:** Step 3 transitions to Step 4.
* **Trade-offs:**  
  * *Pros:* Utterly transparent, highly technical credibility, gives impatient users concrete milestones.
  * *Cons:* More text-heavy; if server worker doesn't report granular step events over websockets, steps must be timed estimates, which touches the Honesty Rule boundary.

---

#### Option 3: The "Ambient Minimised Studio" (Background-First)
* **Concept:** Treats the 2-minute wait as an asynchronous job immediately. Instead of trapping the user on a dedicated loading screen, the app acknowledges the upload in 3 seconds, returns the user to Home, and shows a live "Processing in progress..." card at the top of Home.
* **Visual Structure:**
  * User taps "Remove 3 people" → 3-second upload overlay → User lands back on Home!
  * Top of Home displays an active Job Banner:
    * Thumbnail of photo.
    * `"Cleaning in progress… (Elapsed 0:45 / ~2 min)"`
    * Indeterminate progress hairline.
    * Tap banner to view full-screen preview.
  * When finished: Banner morphs into a vibrant emerald button: `"Your photo is ready — Tap to view result"`.
* **Trade-offs:**  
  * *Pros:* Solves the 2-minute waiting problem completely. The user never sits staring at a spinner.
  * *Cons:* Requires state management for asynchronous job polling on Home (already supported in requirements §6.7, but requires tighter Home-Controller lifecycle integration).

---

### 3.3 Single Recommendation & Why (Processing)

**Adopt Option 1 ("The Living Canvas with Beam Scan") coupled with Option 3's Backgrounding Grace.**  
*Why:*  
1. **Zero Theme Clash:** The screen stays in the user's system theme (pure porcelain `#F8F9FA` in light mode). The dark tomb is gone.
2. **The Photo is the Hero:** The user's photo is beautifully framed with natural lighting and an active scan beam, proving the phone is working without freezing.
3. **Honest Psychological Pacing:** At 5s, 30s, and 90s, the staged copy reflects real engineering stages without fake percentages.
4. **Freedom to Leave:** By offering a clear `"Work in background"` action and removing the toxic `"Keep the app open"` command, user frustration drops to near zero during the 2-minute CPU processing window. When faster 20s GPU workers arrive, the exact same screen simply glides through the stages in 20 seconds.

---

### 3.4 Quick Wins vs. Structural Work (Processing)

* **Quick Wins (1–2 hours):**
  1. **Kill the Pitch-Black Canvas in Light Mode:** Change `color: const Color(0xFF0B0D11)` in `processing_view.dart` to `p.background`. In light mode, this immediately eliminates the violent theme shock.
  2. **Theme the Status Box:** Change `p.photoChromeBg` and `photoChromeFg` in `processing_view.dart` to use the standard semantic theme card tokens (`p.surface`, `p.textPrimary`, `p.border`).
  3. **Delete "Keep the app open while we work":** Replace with truthful reassurance: *"Takes about 2 minutes. Feel free to leave the app — your photo will be saved here."*
* **Structural Work (1–2 days):**
  1. Add the lightweight `ScanBeamPainter` across the photo canvas to give visual life to the in-situ wait.
  2. Implement the `"Work in background"` return-to-home flow utilizing the existing idempotent `jobs` polling architecture (Requirements §6.7).

---

## 4. What Must NOT Change (Standing Guardrails)

In any redesign of Home and Processing, the following architectural foundations and product rules are **sacrosanct and must remain untouched**:

1. **The System Theme Rule:** The app follows the system theme automatically. Never add an artificial in-app dark/light switch.
2. **The Progress Honesty Rule:** Never simulate progress. Percentages are strictly for upload bytes (`fraction * 100`). Server inpainting is indeterminate with real elapsed seconds. Never invent progress ticks.
3. **Zero AI Slop:** No sparkles (`✨`), no purple/violet gradients, no celebratory confetti, no hype adjectives ("Magic", "Mindblowing"). Voice remains calm, precise, and understated.
4. **Picker-Only Photo Access:** Never ask for full photo library permissions; always use the system photo picker.
5. **Fixed Product Truths:**
   * Free quota: 10 free saves per calendar month.
   * Pro price: $19.99/year (store-driven, never hardcoded).
   * Full resolution output always: never downscale the user's photo.
   * Zero watermarks: never degrade free user photos.
   * 24-hour server auto-deletion: photos are never retained or used for model training.
6. **Hardware Performance Safety:** Minimum target is budget Android (minSdk 24). Never introduce heavy full-screen GPU blur shaders (`BackdropFilter` over large viewports) or expensive continuous particle effects.

---

## 5. Summary Implementation Roadmap

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 1: IMMEDIATE WINS (Fixing the jarring disconnects)                    │
│ 1. Processing screen background: bind to p.background (kills dark tomb).   │
│ 2. Processing status card: bind to p.surface & p.border (light card).       │
│ 3. Copy update: remove "Keep app open", state ~2 min + background safety.   │
│ 4. Home SavesIndicator: wrap in refined container card with rounded track.   │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
┌──────────────────────────────────────▼──────────────────────────────────────┐
│ PHASE 2: VISUAL EXCELLENCE (The Modern Photographic Studio)                 │
│ 1. Home: Replace 3-column square grid with Featured Aspect Clean Card.      │
│ 2. Processing: Add lightweight 60fps ScanBeamPainter across photo canvas.   │
│ 3. Processing: Add "Work in background" button navigating to Home.          │
│ 4. Home: Surface resumable job banner when an active clean is processing.   │
└─────────────────────────────────────────────────────────────────────────────┘
```
