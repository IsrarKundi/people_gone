# PeopleGone — Design Direction

**Date:** 2026-10-13
**Author:** UI/UX design agent (PeopleGone)
**Status:** DECIDED direction for MVP UI implementation. All §9 questions ANSWERED 2026-10-13 (see §9). Design/UX authority: design lead (see §10 governance). Binding where it restates `PEOPLEGONE_REQUIREMENTS.md` (product truth) or `FOLDER_STRUCTURE_AND_CONVENTIONS.md` (tokens/code truth). Where this document and those two conflict, they win and this document must be amended.
**Evidence basis:** `DESIGN_RESEARCH.md` (same folder). Every major decision cites the pattern it comes from; anything without a source is labelled **[Inference]**.
**Hard rules honoured throughout:** picker-only photo access; full-resolution output always, never silently downscaled; no watermark ever; the two banned competitor feature names never appear in any proposed in-app copy below; no product features invented beyond the requirements — genuine gaps are scope questions for the owner (§10), never designed in silently.

---

## 1. The direction in one page

**Owner's north star (standing brief, owner's words, 2026-10-13):** the app must feel **"intuitive, easy to understand and use, and modern minimal UI."** Every design decision in this document and every milestone review verdict is judged against this brief first. Where a spec detail and the north star conflict, the north star wins and the spec is amended — with the evidence for the change recorded in the review.

**Name of the direction: "The photo is the app."**

PeopleGone's screens exist to do three things: show the user's photo as large as the phone allows, state plainly what will happen to it, and offer exactly one obvious next action. Everything else — brand, chrome, decoration — is cut until it earns its place against that test.

Five commitments, each traceable to research:

1. **Photo-first, chrome-last.** On every job screen (S3–S7) the photo is full-bleed within the safe area and all controls live in a bottom action zone or a scrim-backed overlay — never in boxes beside the photo, never under a header bar that shrinks it. *(Pattern: Apple Clean Up and Google Photos both edit full-bleed with bottom-anchored tools; the general-editor alternative — Lightroom's layered toolbars — is the density PeopleGone's non-editor user cannot use. Research §9.2.)*
2. **One primary action per screen, named by its outcome.** The button says what will happen and, where a count exists, how much of it: "Pick a photo", "Remove 4 people", "Save photo". Never "Continue", "Next", "Go", "Submit". *(Pattern: TouchRetouch's single "Go" is the manual-era version; PeopleGone improves on it by naming the outcome, because the user is confirming a machine proposal, not their own brushwork. **[Inference]**)*
3. **Calm, factual voice; numbers over adjectives.** Copy states counts, times, and facts ("7 of 10 free saves left", "Deleted from our servers within 24 hours"). No exclamation marks in product copy. No "magic", no "AI-powered" as a headline claim, no sparkle iconography. *(Pattern: Apple's trust-by-verifiable-fact; the shelf's hype copy correlates with its 1★ honesty complaints. Research §2.2.)*
4. **Flat and quiet.** Hairline borders separate surfaces; shadows exist only under sheets and dialogs (already the token rule). No gradients anywhere. No glass/blur panels. No purple/blue "AI gradient" — the single most recognisable generic-AI visual cliché of 2025–26, and an automatic reject under §8. Brand colour appears only on actions and state, never as background wash.
5. **The wait is designed, not decorated.** S3/S6 progress is textual, staged, truthful (real upload %, real per-person counts, indeterminate where duration is unknowable). No looping mascot animation, no fake percentage, no tips carousel. *(Research §3.1.)*

**What PeopleGone must never look like:** a general photo editor (tool grids, filter carousels), a "AI tools" suite home screen (SnapEdit's shape), a subscription app with a utility attached (paywall-first flows, discount badges), or a template Material app (stock cards, stock empty-state illustration, default FAB + drawer).

---

## 2. Design system — refinements to the token baseline

The baseline in Conventions §6 is **kept as-is** unless a change is listed here with its evidence. Implementation remains: tokens only in `core/constants/`, strings only in `core/strings/`, kit widgets only from `core/widgets/`.

### 2.1 Kept unchanged (with the reason recorded)

| Baseline decision | Verdict | Reason |
|---|---|---|
| Primary trust blue `#3157D5` / dark `#8FA8FF`; teal `#0E7C86` / `#45B8C4` | **Keep** | Calm, photographic, non-"AI-purple". No competitor evidence suggests a better-performing alternative; changing brand colour without evidence is slop in the other direction. |
| Cool neutral surfaces, flat + hairline borders, elevation 0 | **Keep** | Matches direction commitment 4; also the cheapest rendering path on low-end devices (NFR-03). |
| Inter bundled (400/600/700/800), NotoSansArabic / NotoNastaliqUrdu for future Urdu; `google_fonts` banned | **Keep** | Inter's numerals are best-in-class for counters/prices; bundling removes a network dependency at first run — a trust and reliability point, not just style. |
| Type scale `display 32 → overline 11`, body floor 13sp | **Keep** | Meets the 13sp floor; `bodySm 13` is reserved for disclosure/caption duty only (see §2.2 R4). |
| Spacing 4-base scale, `screenPadding 16/20`, radii `8/12/16/20/28-sheet`, control heights 52/48/40, 48dp min targets | **Keep** | Consistent with Material baselines in research §9.4. |
| No `screenutil`, fixed dp tokens + breakpoints, `textScaler` clamp 0.85–1.30 | **Keep** | Predictability for an agent-built UI; clamp is the a11y compromise already decided. |
| Dark = system-following, no in-app toggle | **Keep** | Requirements decision; a toggle would be an invented setting. |
| Proposal overlays: red removed / green kept, 55% fill + solid stroke, both themes | **Keep values** | Fixed by Conventions §6.1. The *redundant encoding* around them is added in §2.2 R2 — palette untouched. |

### 2.2 Refinements (each is the *only* kind of change allowed: evidence-based, token-level)

- **R1 — Photo-screen scrim treatment (new tokens, no palette change).** Controls that sit *on* a photo (S4–S7) use `scrim` at the existing 55–60% as a filled pill/bar background with `onPrimary`-equivalent white content in dark *and* light theme. Rationale: legibility must hold against arbitrary photo content, not the scaffold background (Research §9.3). Implement as two new semantic tokens (`photoChromeBg`, `photoChromeFg`) in both palettes — values derived from existing `scrim`/`surface` tokens, no new hues.
- **R2 — Proposal mask redundant encoding (component behaviour, no new colours).** Each person instance gets, in addition to its fill: (a) the existing solid stroke, (b) on tap/selection, a centred label chip reading "Remove" or "Keep" in words, and (c) a distinct stroke style — kept = solid stroke, removed = solid stroke **plus** a subtle diagonal hatch is **rejected** (visual noise at small sizes, **[Inference]**); instead the count sentence above the photo (§4, S4) always reads e.g. "4 people will be removed · You and 1 other are protected" so state exists in text at all times. TalkBack: each instance is a focusable element announcing "Person 3, marked to remove. Double-tap to keep." (Research §5.3, §9.4.)
- **R3 — Progress tokens.** `LoadingOverlay` gains the two sanctioned variants only: *determinate* (bar + % — upload only) and *staged* (stage label + indeterminate bar + optional "N of M" count). No third variant may be invented per-screen. Motion values in §6.
- **R4 — Copy-size floor on money/privacy text.** Price, renewal, free-limit, and deletion statements render at `bodyMd 14` minimum — never `caption 12`. Rationale: the honesty positioning (§1.3 of requirements) is void if the honest text is the smallest text on screen; store subscription rules also require plain, legible terms (CMP-11). This is a usage rule on existing styles, not a new style.
- **R5 — Wordmark.** "PeopleGone" set in Inter 800, `titleLg`, `textPrimary`, no icon-in-a-rounded-square logo lockup on Home; the app icon is a store asset concern, not an in-app one. **[Inference]** — a text wordmark is the honest-utility register; a mascot/gradient mark would contradict commitment 3.

### 2.3 Explicitly rejected refinements

Dynamic colour (Material You) theming — would repaint the trust palette per-user wallpaper and break proposal-overlay contrast guarantees. Skeleton screens with shimmer on photo surfaces — implies content shape we don't have; photo screens use the staged progress instead (skeletons remain fine for History grid thumbnails). Any illustration system beyond the single empty-state mark in §4 S1 — a bespoke illustration set is the fastest route to template-looking filler in an agent-built app.

---

## 3. Global patterns

- **Navigation.** Linear flow only: `Home → (Consent, first time) → Uploading/Analysing → Proposal → [Brush] → Removing → Result → Home`, with History reachable from Home and Settings from Home's app-bar icon. No tab bar, no drawer, no bottom navigation. Back behaviour: Back on S3/S6 = the Cancel action (with its no-cost guarantee stated); Back on S4 discards the job proposal and returns Home (job remains resumable per §6.7 of requirements — surfaced on Home per §4 S1 state C); Back on S7 returns Home with the result retained 24h.
- **App bar.** Present on S1, S9, S10 only (`AppScaffold` standard: title + at most one action). Photo screens S3–S7 have **no app bar** — a floating close/cancel affordance in `photoChrome` treatment (R1) is the only top chrome. This is the full-bleed commitment made concrete. **(Review 01, binding):** on S1 the app-bar content *is* the wordmark — Inter 800, `titleLg`, **left-aligned**, Settings icon button (48dp) at the right. The product name appears **exactly once per screen**, in the app bar; an in-body wordmark/heading repeating it is forbidden on every screen. A centred app-bar title with no trailing action is the template pattern and is rejected.
- **Buttons.** `PrimaryButton` (52dp) is full-width within `screenPadding` on every golden-flow screen, anchored in a bottom action zone with the safe-area inset. `SecondaryButton` (48dp) sits directly above or beside it — never in a toolbar, never icon-only for a golden-flow action. Destructive/leave actions are text-only tertiary, visually last.
- **Sheets.** Consent (S2) and any confirm dialogs use the `radiusSheet 28` top-corner sheet / `AppDialog` shells only. Sheets never contain a scrollable legal wall: S2 shows the verbatim §11.2A copy and a Privacy Policy link, nothing more.
- **Snackbars.** `AppSnackbar` only, for *completed background facts* ("Saved to your photos", "Result deleted from history"). Never for errors that need a decision — those are full states (§4, error taxonomy in Research §8).
- **Haptics.** One light tap confirmation on: person toggle (S4), Remove confirm, Save success. Nothing else. **[Inference]** — restraint keeps the signal meaningful; no haptic on progress ticks.
- **Motion.** §6. All transitions are fades/slides at token durations; the photo itself never scales, bounces, or Ken-Burns.

---

## 4. Screen-by-screen specifications (MVP, S1–S10)

Format per screen: purpose · layout · components · states · copy notes. Copy shown is *direction-level* (exact strings live in `app_strings.dart` and, where the requirements fix wording verbatim, in §11.2 — those are never paraphrased).

### S1 — Home

- **Purpose:** start the one job in one tap; show the allowance honestly; show past work.
- **Layout (top→bottom):** App bar: wordmark (R5) left, Settings icon right. Below: saves status line. Below: primary button. Below: History section (header "History" + grid) filling the rest.
- **Components:** `AppScaffold`, `PrimaryButton` "Pick a photo", saves indicator (see below), `SectionHeader`, history grid (3 cols compact / 4 medium / 5 expanded within the 640dp cap, per Conventions §6.4), thumbnails with date caption (`caption` under each or overlaid — decided: date *below* thumbnail in `textSecondary`, keeps photos clean).
- **Saves indicator:** free users — a plain text line with a thin determinate bar: "7 of 10 free saves left this month." Pro users — text line "Pro · Unlimited saves" with the fair-use reality available in Settings (no badge art, no crown icon). The indicator is *not* a card and *not* tappable for free users (nothing to sell on Home); for Pro it is equally inert. Deliberate-open paywall entry points are the Home *badge* per requirements §9.3 — **DECIDED (§9 item 2, 2026-10-13):** tapping the saves line when at 0 free saves (post-first-result only, per §9.3's never-before-first-result rule) opens S8; otherwise inert.
- **States:**
  - *A — Empty (no history):* wordmark (app bar only — Review 01), saves indicator **with its thin bar**, Pick button, then the teaching line — "Remove background people from a photo. Your subject stays untouched." — and nothing else. **Placement (Review 01, binding):** Home is a single top-anchored column; all gaps are `AppSizes` tokens (no `Spacer`/`Center` vertical centring of content blocks). The line sits **in flow**, `xxxl` (32) below the button, text **left-aligned** to the column, `bodyLg` / `textPrimary`. *(Alignment amended by Review 02, A1: the built left-aligned line sits in the column's rhythm; centred text in a left-aligned column read as a template habit.)* The space below it stays empty — that is correct on first run; a line floating at the viewport's vertical centre is a reject. No "History" header in this state. No illustration beyond, at most, a single before/after thumbnail pair rendered from approved fixture outputs (real pipeline outputs only, mirroring §10.4 store rule). **[Inference]** If fixture art is unavailable at build time, ship text-only; never stock illustration.
  - *B — With history:* as layout above.
  - *C — Resumable job:* if an unfinished job exists (backgrounded/returned), a single slim banner row above the Pick button: "Your last photo is ready" / "…is still processing" → tap resumes. One row, `surfaceVariant`, no dismiss X (it resolves by opening or expiry). This is a state of the job model (requirements §6.7), not a new feature.
- **Copy notes:** no greeting by time of day, no user name (there are no accounts), no upsell line, no "AI" in the saves line.

### S2 — Consent sheet (first upload only, per `consent_version`)

- **Purpose:** one informed decision before the first upload (CMP-03).
- **Layout:** bottom sheet (`ConsentSheet` shell), title, verbatim body copy (§11.2A — lifted exactly, with the configured provider name interpolated), Privacy Policy link, then stacked buttons: Primary "Continue and upload my photo", tertiary "Cancel".
- **States:** single state; re-appears only on `consent_version` bump. Decline → sheet closes, user is on Home, **no** snackbar scolding, no retry nag; the next Pick attempt re-offers the sheet (that is the requirement's blocking design, presented calmly).
- **Layout test (blocking for QA):** full content visible without scroll on a 360×640dp device at text scale 1.30, both themes. If it fails, the fix is sheet height/scroll-of-body-only with buttons pinned — never smaller type (R4 applies: this is privacy text).

### S3 — Uploading / Analysing

- **Purpose:** get the photo to the server and return a proposal, with the user never wondering if it's stuck.
- **Layout:** photo full-bleed (the picked image, shown immediately from the local file — the user should see *their* photo within a frame of tapping Pick), dimmed by `scrim` at low opacity; centred staged-progress block in `photoChrome` treatment; Cancel text action bottom.
- **Stages (exact sequence, `LoadingOverlay` staged variant R3):**
  1. *Uploading* — determinate bar + real % + "Uploading your photo…".
  2. *Analysing* — indeterminate bar + "Finding people…" (requirements' wording).
  3. *Queued (offline)* — no bar; "Waiting for connection. Your photo is saved on this phone and will upload automatically." + "Cancel job" action. (Job queued locally per §6.7.)
- **States:** offline-at-pick enters stage 3 directly. Upload failure after retries → error state per Research §8 class 1 with single action "Retry" (+ tertiary "Pick another photo"). Analysis typed failures (`no_people`, `only_subject`) are **not** errors — they route to S4's plain-message state (§5.4 of research). Analysis >30s → failure state with Retry that polls the same job first (requirements §6.7) — copy: "This is taking longer than usual." + Retry.
- **Motion:** stage change cross-fades the label (200ms); the % bar animates linearly with actual bytes only.

### S4 — Proposal ⭐ (the defining screen)

- **Purpose:** show the machine's proposal so clearly that one tap is an informed decision: these people go, this subject is protected.
- **Layout:** photo full-bleed, pinch-zoomable/pannable (masks move with the photo — masks are rendered in photo coordinates, never screen coordinates). Top: floating close (×) in photoChrome pill. Directly under it, the **status sentence** in a photoChrome pill, always visible, e.g.: "4 people will be removed · 2 protected". Bottom action zone (surface sheet, `radiusSheet`, over the photo's bottom edge): legend row, primary button, secondary Brush row.
- **Masks:** per-instance polygons filled `overlayRemoved`/`overlayKept` at 55% + solid stroke (baseline). On first appearance, masks fade in staggered per person (120ms apart, 200ms each — the only choreographed moment in the app; it teaches "the app found each person" better than any copy). After the intro, masks are static; no pulsing, ever (pulsing reads as alarm and drains battery on a decision screen).
- **Legend row (always visible, in words):** a red swatch + "To remove", a green swatch + "Protected", and a hint "Tap a person to change". Swatches are *samples of the mask treatment*, not plain squares — **[Inference]** showing the actual translucent fill teaches the mapping in one glance.
- **Toggle interaction:** tap a person → fill/stroke swap with a 120ms cross-fade, label chip appears on that person ("Keep" / "Remove") for as long as they remain the last-toggled instance, haptic tick, primary button count updates immediately (FR-05), status sentence updates. Minimum tap target: the instance's bounding area padded to 48dp; overlapping small instances near the keeper get a tap-cycling rule (repeated taps on an ambiguous cluster cycle instances) — implementation note for the builder, flagged here because small/distant people are a named test category (§3.2 of requirements).
- **Primary button:** "Remove 4 people" (live count, singular "Remove 1 person"). Disabled state exists only at 0 selected → button becomes "Remove people" disabled + status sentence explains "Nobody is marked to remove. Tap a person, or use Brush."
- **Secondary:** "Brush" button (48dp, with brush icon) → S5. Tertiary: none.
- **Risk note:** when a remove-marked person touches/overlaps a protected subject, a one-line `warningBg` strip appears directly above the primary button: "This person overlaps your subject — edges may need a touch-up." (Requirements S4.) It never blocks the button.
- **States:**
  - *No background people / only subject:* photo unmasked; centred photoChrome message "There's nobody in the background to remove." + Secondary "Open Brush" + tertiary "Pick another photo". No primary button. (Research §5.4.)
  - *Low keeper confidence:* all-keep default per FR-04, status sentence reads "We couldn't tell who the main subject is, so everyone is protected. Tap the people you want to remove." — the app admits uncertainty in plain words rather than guessing with someone's family photo.
- **Accessibility:** every instance focusable for TalkBack with state announcement (R2); status sentence is a live region; legend is text, not colour-only (Research §9.4 risk 1 — this screen is where that risk is retired).

### S5 — Brush

- **Purpose:** rescue tool only — fix what detection missed, before removal (from S4) or after a result (from S7, crop-local re-run per FR-09).
- **Layout:** photo full-bleed, pinch-zoom/pan. Top photoChrome bar: Undo, Redo, "Done" (primary-weight text action). Bottom action zone: two segmented tools — "Add" / "Erase" (segmented control, 48dp, labels in words with icons), brush-size slider below them with a live circular brush preview, and the brush cursor rendered **offset above the finger** with a loupe-style magnified inset following TouchRetouch's proven pattern (Research §6) — the finger must never hide the mask edge.
- **Mask rendering:** same red fill treatment as S4 for add-to-removal areas; erasing reveals the photo. When entered from S4, the starting canvas is the current shadow-inclusive proposal mask (Research §6, rule 3) — the user edits the real mask.
- **Copy:** one hint line on first entry only: "Paint over anything that should also be removed — including its shadow." (The Lightroom shadow lesson, Research §6, as a single sentence.) Reflections get the same treatment when entered from S7's ghost/reflection context: the hint names the leftover, not a generic tip.
- **States:** Undo/Redo disabled at stack ends (greyed, still 48dp). "Done" with zero edits = plain return (no confirm dialog). Post-result entry: Done label becomes "Fix this area" and triggers the crop-local re-run → routes through S6's staged progress in its short form (single stage, "Fixing…").

### S6 — Removing (progress)

- **Purpose:** survive a 20–45 second server job without anxiety, abandonment ambiguity, or fake feedback. (Research §3.3: this screen has no competitor template; it is designed from honesty principles.)
- **Layout:** the photo full-bleed, dimmed, with completed-person masks shown as cleared (fill fades out) as stages report; original people remain visible until the full result lands on S7. **(§9 item 7, ANSWERED 2026-10-13):** a per-person *live preview* (photo updating person-by-person) is **not** MVP design — API Contract v1 returns one finished photo, no partial results. The builder must not fake intermediate imagery the server didn't send. Live preview is revisited only if a later gateway phase makes partial results cheap.
- **Progress block (photoChrome, centred-bottom above action zone):** primary line "Removing person 2 of 4…" (requirements' per-person copy); indeterminate-or-count bar: the count *is* the determinate signal (segmented bar with M segments filling per completed person — honest because each segment is a completed crop, R3). Below, expectation line set once at entry by job size: "This usually takes under 30 seconds." for warm-size jobs / "First photo of the day can take a little longer." when a cold start is detected server-side — wording APPROVED (§9 item 4, 2026-10-13). **(Review 02, A2 — expectation copy tracks measured reality):** the line must state what is true of the *current* deployment; while the CPU dev worker takes ~2 min/photo, "This can take a few minutes." is the approved line for that deployment, and an elapsed-time display is sanctioned (it is a real measurement). Copy of the "Keep the app open" class is permitted **only** while the implementation genuinely requires the app open, and must be removed when resumable jobs (§6.7 of requirements) land — the resumable design, not the interim copy, is the product.
- **Actions:** "Cancel" tertiary — cancelling consumes nothing and copy says so on the confirm dialog ("Cancel this clean? Nothing will be charged to your free saves."). Backgrounding: job continues; on return, polling resumes and the screen re-renders current state (requirements §6.7); if the job finished while away, the app lands directly on S7.
- **States:** *Busy/queued server-side* → primary line becomes "Busy — your photo is in line." (requirements §8.2 copy register), segments pause, no error styling. *Timeout >90s* → failure state, class 3 (Research §8), single action "Retry" (polls same job first), tertiary "Go Home" (job keeps its 24h result window).
- **Accessibility:** stage/count changes announced via live region at each person completion, not continuously; completion triggers navigation, not a sound.

### S7 — Result

- **Purpose:** judge the result at full quality, then Save / Share / fix — in that order of prominence.
- **Layout:** result photo full-bleed default. Top photoChrome row: close (→ Home), and the compare toggle (see below). Bottom action zone (sheet): primary row "Save photo" + "Share" (secondary, equal height, side-by-side — Share is a first-class outcome for this product's growth, §1.5 of requirements); secondary row: "Brush fix" and "Undo a person" (opens per-person undo: tapping a removed person's *location ghost outline* on the photo restores exactly that person, FR-10 — outlines shown only while this mode is active); disclosure line; "Report this result" as small text action at the very bottom.
- **Compare (FR-13, both mechanisms, non-conflicting — Research §4):**
  - *Hold-to-view-original:* press-and-hold anywhere on the photo shows the original while held, with a small "Original" pill visible during the hold. Release restores the result. Ignores holds that begin on a control.
  - *Slider compare:* the top-row toggle switches the photo into slider mode: a vertical divider with a 48dp handle, draggable across the photo, original left / result right, labels "Before"/"After" in photoChrome pills at the divider's ends. Toggling again exits. This mode is also the non-gesture accessibility path (the handle is TalkBack-adjustable). **(Review 02, A7):** the Before/After pills sit at the photo band's top corners *below* the chrome row (or the chrome reduces to the toggle alone while comparing) — pills must never overlay the close/compare controls.
- **Saves line above the primary row (state-dependent, `bodyMd`, R4):** free user — "Saving uses 1 free save · 7 left after this one"; at 0 left — "You've used this month's free saves" and the Save button routes to S8 (never a dead button); Pro — no line (no meter to explain). GPS/exif fact joins this line once, on first save only: "Location data is removed from saved photos." — **DECIDED (§9 item 5, 2026-10-13):** first-save-only; FR-15's statement duty is met and S7 stays clean thereafter.
- **Ghost notice:** if the second-pass check fired (requirements §6.4 step 5): `warningBg` strip above the action zone — "We think a shadow or outline may be left over." + action "Try fix" (→ S5 post-result mode). Never dismissible into silence: dismissing collapses it to the Brush fix button gaining a warning dot until the job leaves S7. **[Inference]** on the dot; the notice + Try fix themselves are requirements.
- **Disclosure line (verbatim, requirements §11.2B):** "Processed securely · Original deleted from server · Report this result" — rendered as `bodySm` text with "Report this result" as the tappable segment opening the report flow (job ID + optional note; image attaches only on explicit user action, FR-23). **(Review 02, A5):** the Report link wraps as a whole unit or takes its own line — a mid-link orphan ("result" alone on a line) is a reject.
- **Save success:** snackbar "Saved to your photos" + auto-return offer is **rejected** — user stays on S7 (they may still Share); the primary button becomes "Saved ✓" disabled, History has already gained the entry. **[Inference]**

### S8 — Paywall

- **Purpose:** convert a user who is holding a finished, visible result — never a gate before value (requirements §9.3; Research §7).
- **Trigger discipline (testable, §13 of requirements):** only (a) Save tapped at 0 free saves/no Pro, (b) deliberate open (Settings; Home saves line at 0 — see S1 note). Never on launch, never after processing but before the result is *seen*, never as a timed/interstitial prompt anywhere.
- **Layout (top→bottom):** the user's own result photo as the hero (top ~35% of screen, unblurred, unwatermarked — this is a hard rule, not a style choice), close (×) top-right in photoChrome. Headline `headlineLg`: "Keep this photo — and every photo after it." **[Direction copy, APPROVED §9 item 4, 2026-10-13.]** One-line sub: "Pro removes the monthly limit. Free saves return on the 1st." Then the three plan tiles, **all above the fold** on a 360×640 device (acceptance criterion in requirements §13.2 — layout must be tested at that size, both themes, 1.30 text):
  1. **Annual (pre-selected):** tile with `primaryContainer` fill + border in `primary`; "Pro — Yearly", price from store (never hard-coded, §6.3 of requirements), per-month equivalence in `bodySm`, line "Renews yearly. Cancel anytime in Google Play."
  2. **Lifetime (equally visible, second):** same tile size/weight, unselected styling; "Lifetime", price, line "One payment. Yours for good — never moved to a subscription." (Grandfathering stated as a selling fact, §9.3.)
  3. **Monthly (third, not promoted):** same tile; "Pro — Monthly", price, "Renews monthly. Cancel anytime in Google Play."
- **Below tiles:** PrimaryButton "Continue" (label updates with selection: "Continue — Yearly" **[Inference]** for clarity at the store sheet). Then `bodyMd` terms block (R4 — never caption): full price + period + auto-renew + where to cancel, restated in plain sentences. Then a row: "Restore Purchases" (secondary text action) · "Not now" (tertiary). "Not now" copy beneath in `bodySm`: "This photo stays available for 24 hours." (Requirements §9.3/§7.3 — the held result saves without reprocessing if they pay within the window.)
- **Forbidden on this screen (automatic rejects):** countdown timers, strikethrough "was" prices not supplied by the store offering, discount badges, testimonial/rating claims, blurred photo, a close button that is delayed, shrunk, or disguised, pre-ticked anything beyond the Annual selection the requirements mandate, a weekly plan (does not exist), the word "trial" (no trial is offered, §9.2).
- **States:** offerings loading → staged `LoadingOverlay` over the sheet area only (photo stays visible). Offerings failed → error state class: "Prices couldn't load. Check your connection." + Retry; "Not now" remains available — a user must never be trapped on a paywall by a network error. Purchase success → returns to S7 with the held result saveable immediately (no reprocessing), snackbar "You're Pro. This photo is ready to save." Purchase failure → plain error + Retry (FR-22: never silently drop an entitlement state).

### S9 — History

- **Purpose:** the user's saved clean photos, on this phone only — and to say exactly that.
- **Layout:** App bar "History". One line under it (`bodySm`, `textSecondary`): "History lives only on this phone." (Requirements S9 wording register.) Grid as S1's (shared component), newest first, thumbnail + date.
- **Detail (tap):** full-photo view (the S7 photo surface minus editing actions): Share, Delete (destructive confirm via `AppDialog`: "Delete this photo from history? Your original photo is not affected."), close. Deleting removes the local file only.
- **Empty state:** `EmptyView` — one line "Photos you clean will live here." + action "Pick a photo" routing Home. (Distinct line from Home's empty state: Home teaches the job; History explains the shelf.)

### S10 — Settings

- **Purpose:** account-free administration: entitlement, privacy controls, support. A plain list, `listRowMin 56`, grouped with `SectionHeader`s — no cards, no icons-per-row decoration beyond where an icon aids scanning (decided: no row icons; text rows only — the settings list of a one-job app should read like a receipt).
- **Rows (order fixed):**
  1. *Your plan* group: saves counter line (free: "7 of 10 free saves left — resets 1 Nov" with the reset date computed, not generic; Pro: "Pro — Yearly · renews 12 Mar 2027" from store data) · "Go Pro" text action (only when free *and* past first result, mirroring §9.3 discipline) · "Manage subscription" (deep link to store, CMP-11) when Pro · "Restore Purchases".
  2. *Privacy* group: "Privacy Policy" (link) · "How your photos are handled" → read-only sheet restating the consent facts + provider display name from config (never hard-coded) · "Delete my data" (destructive styling; confirm dialog states exactly what is deleted server-side per FR-24, then in-app confirmation of completion).
- **Sheet variants (Review 02, A4):** `ConsentSheet` has exactly two variants — *consent* (Primary "Continue and upload my photo" + tertiary "Cancel"; pre-upload only, S2) and *read-only* (a **single** "Close" action; used by "How your photos are handled"). Two dismiss actions on one sheet is a reject.
  3. *About* group: "Open-source licences" · "Support" (mailto) · "Version" (non-interactive row, `bodySm` value).
- **States:** entitlement unknown/offline — counter row shows last known value with `bodySm` note "Last checked just now / earlier today" **[Inference]**; saves themselves honour the 72h offline grace (requirements §9.4) and the UI must not contradict it by showing an error where a save will succeed.

---

## 5. Component inventory

Built only from the Conventions §6.7 kit; new entries below are the complete list of additions this direction authorises. Anything not listed or in the kit requires an ADR-level justification in review.

| Component | Status | Used on | Notes |
|---|---|---|---|
| `AppScaffold`, `PrimaryButton`, `SecondaryButton`, `LoadingOverlay`, `ErrorView`, `EmptyView`, `AppDialog`, `AppSnackbar`, `ConsentSheet`, `SectionHeader`, `AppCard` | Kit (existing) | Throughout | `AppCard` is expected to be *rarely* used — plan tiles (S8) and the resumable-job row (S1) are its sanctioned uses. Card-ifying ordinary content is a §8 reject. |
| `PhotoSurface` | **New — core/widgets** | S3–S7, S9 detail | Full-bleed photo with pinch/pan, photo-coordinate overlay slot, photoChrome slot. The single most reused new component; masks, brush, compare all render inside it. **Surround rule (Review 02, A3):** one treatment on every photo screen — `background`-token surround, photo contain-fit and centred; any dim/scrim applies to the photo band only, never a different full-screen colour per screen. On-photo chrome is 48dp `photoChrome`, pinned to the photo band's top corners, on the photo. **(Review 03, A8):** a text action on a photo surface that can land off the photo band (S3/S6 Cancel) rides in a `photoChrome` pill (R1) — legibility must not depend on where the band falls; bare text on a photo surface is a reject. |
| `PersonMaskLayer` | **New — features/processing/widgets** | S4 (+ S6 cleared-state) | Renders instances from polygons, handles tap/cycling, label chips, stagger-in. |
| `PhotoChromeBar` / `PhotoChromePill` | **New — core/widgets** | S3–S7 | R1 tokens; the only on-photo chrome. |
| `StagedProgress` | **New — variant of `LoadingOverlay`** (R3) | S3, S6 | Determinate / staged-segmented / queued variants only. |
| `CompareSlider` | **New — features/result/widgets** | S7 | Before/after divider + handle; TalkBack-adjustable. |
| `BrushCanvas` + `LoupePreview` | **New — features/processing/widgets** | S5 | Offset cursor + magnifier inset; brush-size slider with live preview circle. |
| `SavesIndicator` | **New — features/home/widgets** | S1, S10 (row form) | Text + thin bar (free) / text (Pro). Server value is truth; renders a "last checked" nuance only in Settings. |
| `PlanTile` | **New — features/paywall/widgets** | S8 | Selected/unselected from tokens; prices injected from `PurchaseService` offerings only. |
| `HistoryGrid` + `HistoryTile` | **New — features/history/widgets** | S1 (section), S9 | Breakpoint column counts per Conventions §6.4. |

---

## 6. Motion and wait-state design (consolidated)

| Moment | Spec | Duration / curve (tokens) |
|---|---|---|
| Screen transitions in golden flow | Fade + 8dp rise | `normal 200ms`, `easeOutCubic` |
| Sheet present/dismiss (S2, action zones) | Slide from bottom | `slow 320ms`, `easeInOut` |
| Mask stagger-in (S4, once per proposal) | Per-person fade, 120ms stagger | `normal 200ms` each |
| Mask toggle (S4/S5) | Cross-fade fill + chip pop (scale 0.9→1) | `fast 120ms` |
| Compare hold (S7) | Instant swap on press (0ms — any fade makes hold feel laggy); pill fades in | `fast 120ms` for pill only |
| Compare slider (S7) | 1:1 finger tracking, no easing/inertia | — |
| Upload bar (S3) | Linear with real bytes; no smoothing that outruns data | — |
| Segmented progress (S6) | Segment fills when its person completes; fill animates | `normal 200ms` |
| Save success (S7) | Button label swap + snackbar rise | `normal 200ms` |
| Reduced motion | System reduced-motion setting collapses stagger/transitions to pure fades at `fast`; progress and compare are unaffected (they are information, not decoration) | — |

**Wait-state copy discipline:** stage labels are verbs in progress ("Uploading…", "Finding people…", "Removing person 2 of 4…"); expectation lines are set once and never count down; no rotating tips, no "Did you know", no encouragement copy ("Almost there!" is banned — it is a claim the system cannot make honestly near a cold start).

---

## 7. Accessibility specification (beyond the baseline)

Baseline (48dp targets, 4.5:1 text contrast, system text scaling clamped 0.85–1.30, content descriptions) is assumed from Conventions/Material. PeopleGone-specific requirements:

1. **Proposal redundancy (S4):** colour + always-visible text status sentence + per-instance word labels on interaction + TalkBack instance announcements with state and action (R2). QA must include a colour-vision-deficiency simulation pass on S4 in both themes.
2. **Compare without gestures (S7):** slider handle is a focusable, adjustable control ("Before–after comparison, 50%. Adjust to compare."); hold-to-compare is an enhancement, never the only path. A labelled "Before / After" segmented toggle is the fallback if the slider fails QA on small screens.
3. **Announced waits (S3/S6):** stage changes and each completed person are live-region announcements; completion is announced before navigation. No announcement repeats more than once per stage.
4. **Photo descriptions:** user photos carry no alt text by design (private content, CMP-08 — the app never describes photo content); TalkBack on photo surfaces announces only chrome and instance states.
5. **Contrast on photo chrome:** `photoChrome` pill text must meet 4.5:1 against the pill's own scrim background at its lightest specified opacity — tested over white, black, and mid-green (foliage) photo swatches, both themes.
6. **Targets on photo:** mask instances smaller than 48dp use the tap-cycling rule (S4) *and* pinch-zoom remains available; brush slider thumb and compare handle are 48dp hit areas regardless of visual size.

---

## 8. Anti-slop checklist — the QA gate for every milestone review

A build/screenshot is **rejected** if any item fails. Reviewer (this design role) checks every item, in order, against the actual build — not the PR description.

**Identity & honesty**
- [ ] No gradient anywhere; no purple/blue "AI" wash; no sparkle/wand/star iconography; no glassmorphism/blur panels.
- [ ] No banned competitor feature names in any string, asset name, or screenshot (automated lint per CMP-10 plus eyeball).
- [ ] No copy claims not in the requirements: no quality superlatives ("perfect", "flawless", "studio-quality"), no speed claims beyond the approved expectation lines, no "unlimited" without the fair-use context existing one tap away (Settings).
- [ ] No exclamation marks, no emoji, no countdowns, no discount theatre in product copy.
- [ ] Prices/limits/deletion facts appear at `bodyMd` or larger (R4) and prices come from the store offering at runtime (spot-check by changing sandbox price).

**Structure**
- [ ] Exactly one primary button per screen, full-width in the bottom action zone, labelled by outcome (+ live count where FR-05 applies).
- [ ] No tab bar, drawer, tool grid, filter row, "more features" surface, or upsell banner anywhere in the golden flow.
- [ ] Photo screens (S3–S7) have no app bar; photo is full-bleed; all on-photo chrome uses `photoChrome` tokens.
- [ ] No raw colours/sizes/strings in feature code (Conventions §10 test); no card-ification of plain content.
- [ ] Product name appears exactly once per screen, in the app bar (left-aligned wordmark on S1); no in-body wordmark heading anywhere (Review 01).
- [ ] No spacer/centre-driven floating content: empty-state and content blocks sit in the screen's column flow with token gaps only (Review 01).

**The defining screens**
- [ ] S4: keeper is green/protected by default on every fixture; status sentence present and live; legend in words; toggle updates count instantly; overlap warning appears on the overlap fixture; no-people and low-confidence states render as specified.
- [ ] S6: progress is per-person segmented; no fake %; cancel states the no-charge guarantee; busy state uses queue copy, never error styling.
- [ ] S7: both compare modes work and don't conflict; Save line states the meter before the tap; ghost notice appears on the ghost fixture with Try fix; disclosure line is verbatim; Report is reachable without a menu.
- [ ] S8: reachable only via the two sanctioned triggers (test: fresh install cannot reach it before a first result); user's photo unblurred at top; three tiles above the fold at 360×640 @ 1.30 scale; terms at body size; "Not now" works with offerings *failed* as well as loaded; 24h hold copy present.

**States & edge cases**
- [ ] Every screen renders its loading (named stage), error (one recovery action), and empty states — reviewer forces each: airplane mode at pick, mid-upload kill, oversize fixture, 0-people fixture.
- [ ] Backgrounding mid-job and returning lands in the correct state; a job completed while away opens on S7.
- [ ] Light **and** dark pass on every screen; S4 masks legible in both; photoChrome contrast test (§7.5) passes.
- [ ] Text scale 0.85 and 1.30 pass on every screen without truncation of buttons, tiles, or the consent sheet's pinned actions.
- [ ] TalkBack pass: S4 instance announcements, S6 stage announcements, S7 compare handle — all present and sane.

**Taste (reviewer's call, must be justified in the review note if invoked)**
- [ ] Nothing on screen could be mistaken for another app's screen with the wordmark removed — if it could, name the app it resembles; resemblance to SnapEdit's tool grid or a generic Material template is an automatic reject.
- [ ] The screen would still make sense to a non-technical family member with zero instructions — the S4 status sentence and S1 empty line are the benchmarks.

---

## 9. Former questions — ALL ANSWERED (2026-10-13)

**Authority note:** On 2026-10-13 the owner delegated these decisions ("what does the lead agent suggest? do that") and, under the governance recorded in §10, design/UX decisions — including these — are the design lead's, based on the research evidence in DESIGN_RESEARCH.md. Each item below adopts the design lead's spec default. These are closed; reopening any of them requires new evidence, recorded here.

1. **S6 leaving behaviour — ANSWERED: resumable row only, NO completion notification.** A long job may be left; completion surfaces via S1's resumable-job row ("Your last photo is ready"). No system notification: it would need a notification permission the product otherwise never asks for, and the resumable row already guarantees nothing is lost (requirements §6.7). The S6 copy "We'll keep working — come back any time" register stands.
2. **S1 saves-line tap — ANSWERED: tapping the saves line at 0 free saves (post-first-result only) opens S8.** This is the requirements' "Home badge" deliberate-open path (§9.3 of requirements); the saves line is that badge. In all other states the line is inert display.
3. **History shape — ANSWERED: both.** Home carries the history section (shared `HistoryGrid`); the "History" header taps through to the S9 History screen. One component, two surfaces.
4. **Direction copy — ANSWERED: APPROVED.** The proposed lines (S4 status-sentence formats, S4 low-confidence sentence, S6 expectation lines, S8 headline + sub-line, S7 first-save location line) are approved as written in §4. Under §10 governance the design lead owns copy approval going forward; the bar is the calm, factual voice (numbers over adjectives, no hype) — copy that reads as machine-generated filler fails review on that ground alone. **Limit:** money/privacy *facts* in copy (prices, limits, retention, deletion) must match the requirements exactly; governance does not authorise changing a fact, only its wording.
5. **S7 GPS line frequency — ANSWERED: first save only.** "Location data is removed from saved photos." joins the saves line on the user's first save and does not repeat thereafter (FR-15's statement duty is met; repetition would tax every later save).
6. **First-save moment — ANSWERED: confirmed none.** No celebration, no confetti, no rating prompt after the first (or any) successful save. Save success remains the §4-S7 behaviour: button state swap + snackbar. A rating prompt does not exist in the requirements and is not added.
7. **S6 live per-person preview — ANSWERED: NOT for MVP; staged progress stands.** Honest record: the current processing API (Contract v1) returns **one finished photo** — there is no streaming or partial-result channel — so the photo cannot update person-by-person. §4-S6's fallback is therefore the MVP design: photo dimmed, per-person segmented progress, masks clearing as stages report, full result on S7. The API must **not** be designed around per-person preview now. Revisit only if a later gateway phase makes partial results cheap; if it is ever adopted, it returns as a design change with its cost stated.

---

## 10. Governance and review protocol (standing)

**Governance (owner decision, 2026-10-13):**

- **Design and user-experience flow approval authority = the design lead** (this design role). Design decisions — layout, flow, interaction, visual system, and in-app copy — are made by the design lead and must be based on the research evidence in DESIGN_RESEARCH.md, not taste. Owner sign-off is **no longer required** for design or copy decisions.
- **The owner keeps product/business decisions only:** pricing and SKUs, scope (what the product does), and the Phase 0 gate decision.
- **Hard limit on copy authority:** money/privacy *facts* stated in copy (prices, the free limit, fair-use cap, retention/deletion facts, consent facts) must match `PEOPLEGONE_REQUIREMENTS.md` exactly. The design lead owns wording, never facts. Verbatim requirements copy (§11.2) remains untouchable.
- Every screen and review is judged first against the **owner's north star** (§1): intuitive, easy to understand and use, modern minimal UI.

**Review protocol (build phase):**

- Milestone reviews happen on **screenshots + a running build**, per screen, against §8 in order, and against the north star. Verdicts are **Approve** / **Reject with checklist item numbers**. "Looks fine" is not a verdict.
- Copy changes are approved by the design lead in review (see governance). Mechanical string fixes (typos, truncation) need no separate approval.
- Any builder proposal that adds a screen, a navigation level, or a component not in §5 is treated as a **product/scope change**: it returns to the owner as a question, never as a design fait accompli. (Design authority is not scope authority.)
- This document's specs assume the pipeline and API as they stand (Contract v1: one finished photo per job — §9 item 7). An engine or API change that alters what a screen can show (e.g. partial results, materially different job timings) triggers a design-lead re-check of the affected screens (§4-S3/S6 first), recorded as a direction amendment.
