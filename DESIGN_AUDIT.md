# Design, UI & UX Audit: PeopleGone

**Author:** Senior Product Designer  
**Scope:** Complete design, visual system, UI components, and UX flow audit  
**Product:** PeopleGone (Flutter iOS & Android)  
**Deliverable:** Independent Design Audit & Concrete Redesign Proposal  
**Rules & Ground Truth:** Adheres strictly to `PEOPLEGONE_REQUIREMENTS.md` (full-resolution always, system picker only, no watermarks, 10 saves/mo free, $19.99/yr Pro, 24h deletion, no hype copy, zero dead UI).

---

## 1. Overall Verdict

> **The verdict:** The problem is **both** the design direction and its execution. 
> 
> The previous direction committed a fatal philosophical error: it equated **calm and honest** with **sterile, bleak, and unfinished**. In an aggressive attempt to avoid "AI hype tropes" and "marketing slop," it stripped away all visual craftsmanship, warmth, and photographic staging, delivering an ascetic developer wireframe that feels like internal diagnostic tooling rather than a $20/year consumer photo app. 
> 
> The execution compounds this with an enterprise-blue palette, an empty-state home screen that looks like a broken layout, awkward letterbox surrounds with floating dark discs, and an unbuilt Proposal step that forces users to blindly guess who was removed.

---

## 2. Per-Screen Findings

---

### Screen S1: Home (First Run & Empty State)

```
Current Screen Anatomy:
┌──────────────────────────────────────────────┐
│ PeopleGone                              [⚙]  │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │ 10 of 10 free saves left...
│ ┌──────────────────────────────────────────┐ │
│ │               Pick a photo               │ │
│ └──────────────────────────────────────────┘ │
│ Remove background people from a photo.       │
│ Your subject stays untouched.                │
│                                              │
│                                              │
│               [ 80% DEAD VOID ]              │
│                                              │
└──────────────────────────────────────────────┘
```

- **The Problem:** 
  1. **Sterile Accounting Leads the Experience:** The very first element under the header is an administrative quota meter ("10 of 10 free saves left this month") with a progress bar. Before the user has seen what the app does, experienced any value, or trusted the product, we confront them with a consumption budget.
  2. **80% Screen Desert:** Everything is stacked in a tight cluster at the top 20% of the viewport, leaving a vast, flat grey void (`#F7F8FA`) across the rest of the phone. It looks like an error state, a failed network fetch, or an abandoned scaffold.
  3. **Zero Visual Proof or Mental Model:** The app does not show a single photograph. For a photo app, this is disqualifying. The user has to read a dry, clinical sentence ("Remove background people from a photo. Your subject stays untouched.") and take it on faith.
  4. **Enterprise Utility Aesthetic:** Left-aligned Inter text, hairline borders, and an electric corporate-blue button (`#3157D5`) make the app look like an internal IT asset tracker or an expense report tool.
- **Why It Hurts the User:** First impressions determine bounce rate. A user opening this app feels no delight, no photographic confidence, and no clarity on what magic will happen when they tap "Pick a photo." It feels cheap and amateur.
- **Severity:** **HIGH** (First screen every user sees; directly drives onboarding conversion and churn).

---

### Screen S1: Home (With History)

- **The Problem:** 
  1. **Sudden Structural Jolt:** When a photo is finally saved, the empty void is replaced by a "History" section with a 3-column grid of square crops.
  2. **Awkward Square Cropping:** History tiles force arbitrary 1:1 square crops with a harsh border radius, cropping off faces and subjects in portrait or landscape shots.
  3. **Dry Date Subtitles:** Under each crop sits a small, grey date label (`14 Oct 2026`). There is no visual badge or indication of how many people were removed, or how much cleaner the shot became.
- **Why It Hurts the User:** The transition from first-run to recurring use lacks polish; the history grid feels like a generic file explorer rather than a personal gallery of restored memories.
- **Severity:** **MEDIUM**

---

### Screen S2: First-Run Consent Sheet

- **The Problem:**
  1. **Wall of Legal Prose:** Slams the user with a dense block of text right after they picked their first photo. While legally accurate and strictly compliant with §11.2A, it is typeset as an undifferentiated block of body copy.
  2. **Lack of Trust Anchors:** Lacks visual chunking or iconography for the three key reassurance points: (1) Processed securely, (2) Auto-deleted within 24 hours, (3) Never used to train AI models.
  3. **Dual Action Stack:** Stacked primary "Continue and upload my photo" over a plain text "Cancel".
- **Why It Hurts the User:** Users panic when apps mention "uploading your photos to servers" unless the privacy guarantees are scannable in 2 seconds. A dense paragraph causes hesitation and drop-off at the exact moment of intent.
- **Severity:** **MEDIUM**

---

### Missing Screen: S4 Proposal (The Critical Product Gap)

```
Current Flow (Broken Blind Run):
[Pick Photo] ──> [Processing Spinner] ──> [Result (Someone missing!)] ──> [Hunt for "Kept wrong person?"]

Intended / Required Flow:
[Pick Photo] ──> [Proposal Screen: Green vs Red Overlays] ──> [Confirm 1-Tap] ──> [Flawless Result]
```

- **The Problem:** 
  1. **The Core Promise is Missing:** The app's defining value proposition in `PEOPLEGONE_REQUIREMENTS.md` is: *"It finds everyone. You tap once."* But Screen S4 (Proposal) is **completely missing from the app code**.
  2. **Blind Execution:** The app jumps directly from photo pick into processing, automatically removes whoever the backend heuristic decided to delete, and drops the user onto the result screen.
  3. **Catastrophic Keeper Recovery:** If the algorithm guessed wrong and removed the user's daughter or husband, the only recourse is a text button at the bottom of the result screen: *"Kept the wrong person?"*.
  4. **The "Person 1 vs Person 2" Blind Sheet:** Tapping *"Kept the wrong person?"* opens a bottom sheet (`KeeperSheet`) that lists:
     - `Person 1 (kept)`
     - `Person 2 (removed) [Keep this person]`
     - `Person 3 (removed) [Keep this person]`
     **There are zero thumbnail face crops! Zero location indicators!** The user has no idea which number corresponds to which person in their photo!
- **Why It Hurts the User:** This is an extreme usability failure. Users cannot identify their loved ones from abstract integer IDs (`Person 2`). It turns an accidental removal into a guessing game.
- **Severity:** **HIGH (CRITICAL)**

---

### Screen S3 / S6: Processing View

- **The Problem:**
  1. **Letterbox Lettering & Scrim Mismatch:** The picked photo is placed inside a `BoxFit.contain` frame. When aspect ratios don't match the phone, massive grey letterbox bands appear. The scrim only covers the image band, while the letterbox shows the background scaffold, creating an ugly, fragmented sandwich.
  2. **The "Administrative" Progress Box:** Progress is shown inside a floating rounded box with a 4px generic `LinearProgressIndicator`, a running digital stopwatch (`0:04`), and text: *"Finding people and removing them... Keep the app open while we work."*
  3. **Anxiety-Inducing Wait:** For processing that can take 15 to 40 seconds on remote workers, watching an indeterminate line bounce back and forth alongside a ticking second counter feels agonisingly slow. There is no subtle micro-animation, no progressive scanline, and no visual indication that the engine is intelligently analyzing the scene.
  4. **The "Cancel" Pill Disconnect:** A dark pill button with "Cancel" floats awkwardly below the progress box, disconnected from the visual hierarchy.
- **Why It Hurts the User:** Time feels twice as long when watching an indeterminate bar and a raw seconds counter. The screen looks like a terminal process download dialog.
- **Severity:** **HIGH**

---

### Screen S7: Result Screen & Compare

```
Current S7 Anatomy:
┌──────────────────────────────────────────────┐
│ (X)                                     (⇆)  │ <- Floating dark discs
│                                              │
│              [ Result Photo ]                │
│                                              │
├──────────────────────────────────────────────┤ <- Hard hairline border
│ 3 people removed (1 kept)                    │
│ Saving uses 1 free save · 9 left after this  │
│ Location data is removed from saved photos.  │
│ ┌──────────────────────┐┌──────────────────┐ │
│ │     Save photo       ││      Share       │ │
│ └──────────────────────┘└──────────────────┘ │
│ Kept the wrong person?                       │
│ Processed securely · Deleted · Report result │
└──────────────────────────────────────────────┘
```

- **The Problem:**
  1. **Floating "PhotoChrome" Circles:** The top of the screen features two raw, 48dp dark translucent circles pinned to the corners of the photo band: a Close `(X)` and a Compare `(⇆)` icon. When a photo is portrait or landscape, these circles float awkwardly inside or outside the frame.
  2. **Hairline Border Cutoff:** The photo abruptly terminates at a horizontal hairline border (`#DFE3E9`), below which sits a white rectangular bottom panel crammed with text.
  3. **Accounting Lecture Under the Photo:** Before saving, the user is forced to read three separate lines of administrative and technical disclosure:
     - *"3 people removed (1 kept)"*
     - *"Saving uses 1 free save · 9 left after this one"*
     - *"Location data is removed from saved photos."*
  4. **Side-by-Side Button Cram:** "Save photo" (primary) and "Share" (secondary) are forced into a rigid 50/50 horizontal split. On smaller devices, this constricts button padding and looks crowded.
  5. **Compare Mode Clashes:** While the `CompareSlider` functionally works, entering compare mode spawns "Before" and "After" pill tags that fight for visual attention with the top chrome buttons.
  6. **Disclosure & Report Clutter:** The footer line *"Processed securely · Original deleted from server · Report this result"* looks like legal fine print stuck under the buttons.
- **Why It Hurts the User:** The "Aha! Look at my clean photo!" moment is completely suffocated by fine print, warnings, quota counters, and rigid buttons. Instead of feeling proud of their photo, the user feels like they are completing a tax return.
- **Severity:** **HIGH**

---

### Screen S9: History (Grid & Detail)

- **The Problem:**
  1. **Empty State is an Abandoned Icon:** When empty, it shows a tiny outlined folder icon and a single sentence: *"Photos you clean will live here."* No warm illustration, no prompt to clean a photo, no personality.
  2. **History Detail View is Barren:** Tapping an image opens a screen showing the photo contain-fit, a hairline border, the date (`14 Oct 2026`), a full-width "Share" button, and a stark red text link: *"Delete"*.
  3. **No Compare in History:** Once saved to history, the user can no longer view the original or slider-compare what was removed. The magic of the tool is erased; it just acts like a second, inferior camera roll.
- **Why It Hurts the User:** History feels like a dead archive rather than a gallery of achievements.
- **Severity:** **LOW - MEDIUM**

---

### Screen S10: Settings

- **The Problem:**
  1. **Receipt-Like Density:** Styled deliberately as a "receipt," it presents flat text rows separated by massive white gaps (`xxl: 24`).
  2. **Visible Plumbing:** Exposes backend infrastructure choices directly to the user: *"Processing provider: PeopleGone's processing servers"*. A consumer photo app does not need to list its server infrastructure as a top-level settings row unless required by regulatory disclosure.
  3. **No Visual Hierarchy:** Plan status, privacy links, and support are rendered with the exact same weight, font, and row height.
- **Why It Hurts the User:** Monotonous, dry, and lacking the polish expected of a modern mobile app.
- **Severity:** **LOW**

---

## 3. Benchmark: Why Competitors Feel Premium (and What to Steal vs Avoid)

| Competitor | What They Do Right (Patterns to Adopt) | What They Do Wrong (Anti-Patterns to Avoid) | Direct Application to PeopleGone |
|---|---|---|---|
| **Apple Photos (Clean Up)** | • **Immersive Dark Surface:** The entire photo editing workspace is dark (`#000000`/`#121214`), making photo colors pop.<br>• **Subtle Glowing Canvas:** Detected people have a luminous, soft iridescent sheen rather than opaque red slabs.<br>• **Single Tap Undo:** Floating, ultra-compact pill actions that stay out of the photo's way. | • Restricted only to Apple Intelligence hardware.<br>• Often over-blurs or hallucinates textures. | **Adopt:** An edge-to-edge dark editing workspace where the photo is the sole star. Replace harsh 55% red polygons with soft-edged, glowing accent tints. |
| **Google Photos** | • **Haptic-Rich Slider:** Smooth before/after comparison with subtle haptic feedback on center-crossing.<br>• **Warm, Human Typography:** Friendly, reassuring microcopy that treats the photo as a memory. | • Cloud backup prompts constantly interrupt the flow.<br>• Hidden behind multiple sub-menus. | **Adopt:** Beautiful, fluid slider handles with central haptic detents. Keep all copy humble, reassuring, and concise. |
| **TouchRetouch** | • **Focused Single-Purpose Ergonomics:** Designed for one thing: removing unwanted elements cleanly.<br>• **Floating Bottom Toolbar:** Minimal floating dock with clean iconography and thumb-reachable triggers. | • Antiquated, utilitarian UI with cluttered technical tools.<br>• Complex manual lasso/brush requirements. | **Adopt:** The focused, distraction-free floating bottom capsule. Single-job speed. |
| **SnapEdit** | • **Interactive Before/After Demo on Empty State:** Users can drag a sample before/after image on first launch to immediately understand the magic.<br>• **Face Crop Selector:** Shows small circular face thumbnails of detected people to tap and keep/remove. | • **Aggressive Paywalls:** Full-screen popups immediately on open.<br>• **AI Hype Copy:** Sparkle icons, "Magic AI!" banners everywhere.<br>• **Watermarks & Degradation:** Heavy watermarking on free tiers. | **Adopt:** The interactive sample before/after card on Home S1! The circular face crop chips for keeper selection.<br>**Avoid:** Paywall harassment, sparkle copy, watermarks. |
| **Photoroom** | • **Fluid Processing Animation:** While background is being removed, a subtle luminous scanline sweeps across the image.<br>• **Instant High-Res Feedback:** Seamless transition from processing to crisp result. | • Complex layers, stickers, and e-commerce templates cluttering the view.<br>• Forces account creation. | **Adopt:** The luminous scanline pulse during processing (replaces the dreary progress bar). |

---

## 4. Why the Current App Looks Cheap & Amateur

1. **The "Developer Admin" Color Palette:** 
   `#3157D5` (primary) is the exact blue used by enterprise IT consoles, insurance dashboards, and bootstrap templates. Combined with `#0E7C86` (teal) and light grey borders (`#DFE3E9`), it has zero connection to photography, art, or lifestyle.
2. **The "Empty Wireframe" First Run:**
   Leaving 80% of the screen blank on first launch makes the app look broken. Professional apps *never* leave prime viewport real estate empty; they showcase a live, interactive demonstration of their capability.
3. **Severe Hairline Border Syndrome:**
   Dividing every view with `Border(top: BorderSide(color: p.border))` is a web-desktop habit from 2014. Modern mobile UI uses layered elevation, rounded floating cards, tonal shifts, and background blurs to separate planes.
4. **Text-Heavy Anxiety Displays:**
   Displaying quotas, reset dates, deletion rules, and EXIF notes as four stacked paragraphs under the photo makes the UI feel insecure and bureaucratic.
5. **No Visual Media in Decision Making:**
   Asking the user whether "Person 1" or "Person 2" should be kept without showing their face is the textbook definition of a developer-centric UI leak.

---

## 5. Concrete Redesign Proposal

To turn PeopleGone into a sleek, trustworthy, modern photo app that users love opening, here is the architectural redesign under all non-negotiable product constraints.

### Visual Architecture: "The Darkroom Studio"

#### Why Darkroom Studio?
Photography belongs on dark surfaces. Look at Lightroom, Apple Photos, Darkroom, and camera viewfinders. When you place a photo against a bright white or grey background (`#F7F8FA`), the eye's pupils contract, contrast perception drops, and letterboxing looks awful. On a deep, rich dark studio canvas (`#0D0F12`), photos look vibrant, letterboxing disappears into the canvas, and floating controls look modern and native.

---

### Design System Tokens & Specs

#### 1. Color Palette (Dark-First Studio & Pure Clean Light)

```
Token                  Dark Mode (Primary)      Light Mode (Optional System Follow)
───────────────────────────────────────────────────────────────────────────────────
surfaceCanvas          #0B0D10 (Deep Obsidian)  #F9FAFB (Clean Porcelain)
surfaceCard            #16191F (Card Surface)   #FFFFFF (Pure White)
surfaceElevated        #21252E (Floating Dock)  #F0F2F5 (Tonal Pill)
borderSubtle           #282C37 (Soft Charcoal)  #E5E7EB (Soft Grey)

accentPrimary          #3B82F6 (Vibrant Cobalt) #2563EB (Rich Blue)
accentPositive         #10B981 (Emerald Keep)   #059669 (Emerald)
accentDestructive      #EF4444 (Crimson Remove) #DC2626 (Crimson)

textHighContrast       #FFFFFF (Pure White)     #111827 (Near Black)
textMediumContrast     #9CA3AF (Muted Silver)   #4B5563 (Slate Grey)
textLowContrast        #6B7280 (Discreet Grey)  #9CA3AF (Caption Grey)

glassScrim             rgba(11, 13, 16, 0.72)   rgba(255, 255, 255, 0.85)
glassBlur              ImageFilter.blur(16, 16) ImageFilter.blur(16, 16)
```

#### 2. Typography Rhythm (Inter)
- **Wordmark & Screen Titles:** Inter SemiBold (600), 20sp, letter spacing -0.4px.
- **Hero / Value Statements:** Inter Medium (500), 16sp, textHighContrast.
- **Body & Captions:** Inter Regular (400), 14sp, textMediumContrast.
- **Badges & Metrics:** Inter SemiBold (600), 12sp, tabular figures (`FontFeature.tabularFigures()`).
- **Button Labels:** Inter SemiBold (600), 15sp.

#### 3. Component System
- **Floating Glass Capsule (Bottom Dock):** Rather than a full-width rectangular sheet with a hard top border, editing and action controls sit inside a floating, rounded capsule (`borderRadius: 32`, background: `surfaceElevated` with subtle glass blur, elevation 8).
- **Interactive Before/After Hero Card:** An interactive slider card pre-loaded with an approved real pipeline sample (e.g. landmark photo with tourists gone).
- **Face Crop Selector Chips:** Circular 48dp avatar chips showing the detected person's actual face, ringed in Green (Keep) or Red (Remove).

---

### Detailed Screen-by-Screen Redesign

---

#### S1: Home Screen (Reimagined)

```
┌──────────────────────────────────────────────┐
│  PeopleGone                             [⚙]  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ [Interactive Before/After Demo Card]   │  │
│  │                                        │  │
│  │                [ | ]                   │  │
│  │   Before        <|>         After      │  │
│  │                                        │  │
│  │  "Drag to preview automatic clean"     │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Automatic stranger removal.                 │
│  Full resolution. Private.                   │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │        [+] Select a Photo              │  │ <- Floating Primary Button
│  └────────────────────────────────────────┘  │
│                                              │
│      [●●●●●●●○○○]  7 of 10 free saves left    │ <- Discreet Dot Meter
└──────────────────────────────────────────────┘
```

1. **Header:** 
   - Left: `PeopleGone` wordmark in crisp Inter SemiBold.
   - Right: Sleek Settings gear icon (`24dp`, in a soft circular hover/tap container).
2. **Interactive Hero Card (The Proof):**
   - Positioned prominently in the top half of the screen.
   - An interactive before/after split card showcasing a real pipeline demonstration (e.g. a tourist landmark with strangers cleanly removed).
   - The user can drag the slider handle immediately upon first launch! This provides **instant proof** of value in under 2 seconds without uploading a thing.
3. **Value Tagline:**
   - Calm, confident, two lines:
     *"Automatic background removal.*  
     *Full resolution · Stays private"*
4. **Primary Action ("Select a Photo"):**
   - High-contrast, tactile floating pill button (height 56dp, `radius: 28dp`).
   - Icon: subtle photo gallery plus icon.
   - Triggers the native system picker immediately.
5. **Discreet Saves Meter:**
   - Relocated *below* the main action as a subtle, elegant meter:
     `[●●●●●●●○○○] 7 of 10 free saves left this month`
   - Doesn't shout; doesn't lecture. It is honest, transparent, and respectful.
6. **With History State:**
   - The demo card shrinks or transitions smoothly into a modern "Recent Cleans" horizontal carousel or 2-column masonry grid, showing clean edge-to-edge aspect thumbnails with subtle shadow depth.

---

#### S2: Consent Sheet (Reimagined)

1. **Format:**
   - Native bottom sheet with `radius: 24dp`, frosted dark glass background.
2. **Visual Reassurance Anchors (3 Scannable Bullets):**
   Instead of a dense text paragraph, format §11.2A requirements into 3 clear, scannable value rows with subtle icons:
   - 🔒 **Private Processing:** Uploaded via encrypted connection solely to remove background people.
   - ⏱️ **Deleted in 24 Hours:** Photos are permanently erased from processing servers within 24 hours.
   - 🚫 **Never Used for Training:** Your personal photos are never stored or used to train AI models.
3. **Buttons:**
   - Primary: *"Continue to Upload"* (52dp pill).
   - Secondary: *"Cancel"* (subtle text button).
   - Underline link: *"Privacy Policy"* in muted text.

---

#### S4: Proposal Screen (Restoring the Missing Golden Screen)

```
┌──────────────────────────────────────────────┐
│ (X)                                     (↺)  │
│                                              │
│                 [ PHOTO ]                    │
│            ┌──────┐                          │
│            │ Keeper│ (Protected)             │
│            └──────┘                          │
│          ░░░░░░░░░░░░░░░░                    │
│          ░ 3 to Remove ░ (Glowing Soft Red)  │
│                                              │
│ ┌──────────────────────────────────────────┐ │
│ │  Who to keep:                            │ │
│ │  [ (☺) You ]  [ ✖ Person 2 ]  [ ✖ Person 3]│ │ <- Face Crop Chips!
│ │                                          │ │
│ │  ┌────────────────────────────────────┐  │ │
│ │  │       Remove 3 People (1 Tap)      │  │ │ <- Primary Action
│ │  └────────────────────────────────────┘  │ │
│ └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

1. **Visual Proposal Overlay:**
   - Keeper (subject): Subtle thin emerald green outline with a floating micro-chip: *"Protected"*.
   - People to remove: Soft translucent warm red wash (not an ugly opaque block).
2. **Interactive Face Chips ("Who to keep"):**
   - Above the primary button, a horizontal row of 44dp circular avatar chips showing **actual cropped face previews** of every person detected in the photo!
   - Tapping an avatar toggles them instantly between Keep (Green check) and Remove (Red cross).
   - **No more "Person 1 vs Person 2"!** The user immediately taps their child's or partner's face to protect them.
3. **Outcome Button:**
   - Dynamically updates: *"Remove 3 People"* (or *"Remove 1 Person"*).

---

#### S3 / S6: Processing Screen (Reimagined)

1. **Atmosphere:**
   - Full-bleed photo, subtly darkened (40% obsidian scrim).
2. **Visual Luminous Scanline:**
   - A soft, elegant vertical or horizontal light beam slowly glides across the photo once or twice, indicating an intelligent photographic scan is underway.
3. **Floating Progress Capsule:**
   - Bottom floating capsule with frosted glass blur.
   - Staged status indicator:
     - `Uploading (42%)...`
     - `Identifying people...`
     - `Reconstructing background...`
   - Honest elapsed time displayed cleanly: `12s elapsed · Usually takes ~25s`.
4. **Cancel:**
   - Subtle, clean dismiss button. Never penalizes the user's quota.

---

#### S7: Result & Compare Screen (Reimagined)

```
┌──────────────────────────────────────────────┐
│ [← Back]                            [⊞ Share]│
│                                              │
│                                              │
│             [ Cleaned Photo ]                │
│                                              │
│                                              │
│     ┌──────────────────────────────────┐     │
│     │   [ ◄ Hold to Compare ► ]        │     │ <- Floating Pill
│     └──────────────────────────────────┘     │
│                                              │
│ ┌──────────────────────────────────────────┐ │
│ │  3 people removed · Full resolution      │ │
│ │                                          │ │
│ │  ┌────────────────────────────────────┐  │ │
│ │  │            Save Photo              │  │ │ <- Dominant Primary Button
│ │  └────────────────────────────────────┘  │ │
│ │  [ ✎ Wrong person kept? ]   [ ℹ Details ]│ │
│ └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

1. **Maximum Photo Immersion:**
   - No hard hairline borders. The photo fills the screen naturally.
   - Letterboxing melts invisibly into the `#0B0D10` background.
2. **Tactile Compare Pill:**
   - A sleek, floating glass pill anchored at the bottom-center of the photo:
     `[ ◄ Hold or Slide to Compare ► ]`
   - Supports both: quick long-press anywhere to flash original, or drag the pill to slide split. Smooth haptic tick when crossing the center.
3. **Floating Action Dock:**
   - **Primary Action:** Large, full-width *"Save Photo"* pill button.
   - **Secondary Actions:**
     - Left: *"Wrong person kept?"* (Clean text action that re-opens the face selector without losing the job).
     - Top bar: Top-right Share icon (`24dp`) for immediate sharing without saving twice.
4. **Micro-Disclosure Drawer:**
   - Replaces the 4 lines of legal text with a clean one-line status:
     *"Saved photo will use 1 save (9 remaining) · Stored full resolution"*
   - Tapping *"Details"* or info icon reveals the full deletion / report options in a tidy mini-sheet.

---

#### S9 & S10: History & Settings (Reimagined)

1. **History:**
   - Dynamic 2-column or 3-column photo grid with natural aspect ratios (masonry) and soft rounded corners (`12dp`).
   - Tapping an item opens full-screen view **with the Before/After slider still functional** (cached locally for the session/history file)!
2. **Settings:**
   - Modern grouped cards with soft `#16191F` background.
   - Card 1: **Membership & Saves** (Visual progress meter, "10 saves reset on Nov 1", "Upgrade to Pro").
   - Card 2: **Privacy & Security** (Direct toggles / links to "How your photos are handled", "Delete all server data").
   - Card 3: **Support & Version** (Clean mailto link, build version).

---

## 6. Two Alternative Visual Directions (Trade-Off Analysis)

If the owner prefers a different flavor from the recommended **Darkroom Studio**, here are two alternatives:

### Direction B: "Swiss Editorial / Pure Light"
- **Aesthetic:** Minimalist monochrome, pure white surfaces (`#FFFFFF`), deep obsidian typography (`#0A0A0A`), crisp 1px borders, generous whitespace, zero blue tint.
- **Inspiration:** VSCO, Leica FOTOS, Kinfolk design systems.
- **Pros:** Feels extremely premium, high-art, and calm. Eliminates any resemblance to generic AI apps.
- **Cons:** Photos with white or light skies bleed into the screen edges; high battery consumption compared to OLED dark mode.

### Direction C: "System Native Pro (Cupertino / Material 3 Expressive)"
- **Aesthetic:** Uses 100% native platform semantics. iOS gets native frosted glass navigation bars, SF Pro typography, and standard modal sheets. Android gets Material 3 surface tinting and dynamic floating pills.
- **Inspiration:** Apple Camera / Photos, Google Camera.
- **Pros:** Feels like a built-in OS tool. Zero learning curve for non-technical users.
- **Cons:** Less distinct brand identity; requires maintaining two visual design branches in Flutter.

---

## 7. Actionable Priority Roadmap

Split specifically for a solo developer to implement efficiently:

### Phase 1: Quick Wins (< 1 Day — Immediate High-Impact Polish)

1. **Kill the Home Void (Add Visual Hero):**
   - Replace the 80% blank space on Home S1 with an interactive or animated Before/After sample card using existing fixture assets (`app/test/fixtures/photos/`).
2. **Deprecate the Corporate Blue Palette:**
   - Update `app_colors.dart`: Switch `primary` from the harsh `#3157D5` to rich `#2563EB` (or Obsidian Black `#111827` for high-contrast luxury) and background to `#0B0D10` (Dark) / `#F9FAFB` (Light).
3. **Move the Quota Meter Off the Top:**
   - On Home, move the "10 of 10 saves left" below the primary "Pick a photo" button. Lead with value, not limits.
4. **Fix S7 Result Button Cram:**
   - Make "Save Photo" the dominant full-width primary button. Move "Share" to the top-right app bar action.
5. **Humanize the Consent Copy:**
   - Convert the dense consent paragraph in `consent_sheet.dart` into 3 bullet points with checkmark/lock icons.

### Phase 2: Structural Changes (1–3 Days — Foundation & UX Integrity)

1. **Build Screen S4 (Proposal Screen):**
   - Implement the proposal confirmation screen. Even before multi-polygon backend arrives, show detected person bounding boxes with face crop thumbnails.
2. **Thumbnail-ify the Keeper Sheet:**
   - In `keeper_sheet.dart`, render cropped face thumbnails next to each detected person instead of abstract text labels like "Person 1" and "Person 2".
3. **Replace the S6 Processing Bar with Luminous Sweep:**
   - Remove the digital seconds counter (`0:04`) and indeterminate bouncing line. Replace with a smooth scanline sweep or subtle breathing opacity pulse over the dimmed photo.
4. **Remove Hairline Border Cutoffs on S7:**
   - Redesign S7 bottom area from a hard bordered sheet into a floating action dock with 24dp corner radii.
5. **Enable Compare on History Detail:**
   - Store the original thumbnail/preview alongside the clean result so the user can show off the before/after wipe to friends straight from History.

---

## 8. What to KEEP As-Is (The Strong Foundation)

Do **not** discard everything. Several core engineering and UX principles in this repo are stellar and must be preserved:

1. **The Factual, Calm Voice (No AI Sparkle Slop):**
   - The refusal to use words like "AI Magic," "Magical Eraser," or sparkle emojis is 100% correct. Keep the calm, honest tone.
2. **Strict Quota & Metric Honesty:**
   - Stating "Saving uses 1 save · 9 left after this" before the tap is genuinely respectful and builds long-term user trust. Keep the rule; just refine the typography.
3. **The System Photo Picker Rule:**
   - Never requesting full photo library access is a massive privacy selling point. Keep this strictly picker-only.
4. **Zero Watermarks & Full Resolution Guarantee:**
   - This sets PeopleGone apart from sleazy competitors. Never compromise on full-resolution output.
5. **Dual Compare Modes (Hold + Slider):**
   - Having both quick hold-to-compare and precise slider comparison is a benchmark-tier feature. Just polish the handles and pill placement.
6. **Architecture & Clean Codebase:**
   - The tokenized constants, GetX bindings, and strict service boundaries are clean and fast. The redesign requires zero architectural rewrites—only styling and layout refactoring.

---
*End of Design Audit.*
