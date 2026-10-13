# PeopleGone — Design Research

**Date:** 2026-10-13
**Author:** UI/UX design agent (PeopleGone)
**Status:** Research record. Not normative. Product truth is `PEOPLEGONE_REQUIREMENTS.md`; binding conventions are `FOLDER_STRUCTURE_AND_CONVENTIONS.md`. Decisions distilled from this research live in `DESIGN_DIRECTION.md`.
**Labelling:** Every pattern below is tagged **[Verified pattern]** (observed in a named shipping product / documented source), **[Requirements]** (already decided in the requirements), or **[Inference]** (my judgement applying a pattern to PeopleGone — not a fact about the source app).
**Competitor naming note:** Competitor feature names appear in this research document only, for analysis. They must never appear in PeopleGone app copy, store metadata, or marketing (Requirements hard rule, AGENTS.md).

---

## 1. What was studied and why

PeopleGone does one job: pick a photo → app finds every background person → user confirms → people are removed server-side → full-resolution save. Six shipping products handle part or all of that job today. Each was studied for a different question:

| Product | Why it matters for PeopleGone |
|---|---|
| Google Photos editor (incl. its generative edit tools) | The default editor for our Android target user; defines user expectations for tap-to-select editing, compare, and save-as-copy. Also the origin of the "10 free saves/month" mental model. |
| Apple Photos — Clean Up flow | The best-executed "suggested removal" flow: automatic highlighting, tap to remove, brush/circle as fallback, fully on-device trust story. Also our Phase 0 quality comparator. |
| TouchRetouch | The quality/trust leader among dedicated removal apps (58,146 US iOS ratings, 4.74★ — Requirements §1.2, verified 2026-10-12). Manual-first. Shows what 14 years of brush UX refinement looks like — and what its pricing backlash teaches. |
| SnapEdit | The closest focused rival (~21M Android downloads, 4.46★ — Requirements §1.2). The only major rival whose default flow is auto-detect-then-tap. Also the shelf's clearest example of free-tier hostility (1,600px cap + watermark + ads). |
| Adobe Lightroom mobile — Generative Remove / Remove tool | Pro-grade removal inside a general editor: brush selection, shadow lessons, object-aware vs generative modes, non-destructive stack, variations. Shows the density ceiling PeopleGone must stay far below. |
| Snapseed (incl. 3.0 redesign) | Google's free standalone editor. Lessons in home-screen shape (edited-photo grid + one big entry button), tab organisation, and the cost of hidden gestures and fixed brush sizes. |

Sources are listed in §10. Where a claim rests on the requirements' own verified research (ratings, caps, pricing), it is cited to the requirements rather than re-derived.

---

## 2. First-run and trust building

### 2.1 Nobody teaches the job with a carousel anymore — the product teaches it

- **[Verified pattern] Apple Clean Up:** there is no onboarding tour. The first time the tool is opened it downloads its model, then instructs in one line: tap, brush, or circle what you want removed. Suggested items glow. The teaching *is* the first real use, on the user's own photo. (Apple support coverage and hands-on guides, §10.)
- **[Verified pattern] TouchRetouch:** ships per-tool in-app tutorials (book icon on Home) rather than a first-run tour. Users who never need Clone Stamp never see its tutorial. Teaching is stored by tool, pulled on demand.
- **[Verified pattern] Snapseed 3.0:** opens to a grid of your previously edited photos with one prominent circular button to open the system picker. No welcome screens stand between launch and work for a returning user.
- **[Requirements]** PeopleGone S1 Home is already specified bare: wordmark, one primary "Pick a photo" button, saves counter, history grid, Settings. Empty state = one line explaining the one job + the Pick button. No feed, no banner.
- **[Inference]** PeopleGone should have *zero* first-run screens before S1. The trust/teaching load that other apps spread across onboarding is carried in PeopleGone by three specified moments instead: the consent sheet (S2, first upload only), the proposal screen (S4, where the user sees their own family protected in green — the single most persuasive screen in the app), and the first result (S7). Any screenshot carousel before the first pick would delay the only moment that converts.

### 2.2 Trust is stated in facts, not adjectives

- **[Verified pattern] Apple** leans on a verifiable fact — processing happens on-device, nothing is sent to a server — and repeats it in coverage until it becomes the feature's reputation. PeopleGone cannot claim that fact (processing is server-side by architecture, §6.4), so it must substitute equally verifiable facts.
- **[Requirements]** PeopleGone's verifiable facts are already written: picker-only access ("does not access the rest of your library"), deleted when processing finishes and in all cases within 24h, never used to train AI models (CMP-07 wording), GPS stripped on save (FR-15), prices and the free limit shown before processing starts (FR-25).
- **[Verified pattern — negative] SnapEdit / category shelf:** the loudest complaint pattern across the removal-app shelf is the *discovered* paywall — limits, watermarks, and resolution caps revealed at export, after the work is done (Requirements §1.3, UF-08…UF-12). TouchRetouch's current backlash follows the same shape: a licence change discovered at export time by past buyers.
- **[Inference]** The trust pattern to copy is Apple's *specificity*, not its claim. Every trust statement in PeopleGone must be a checkable fact with a number or a mechanism ("deleted within 24 hours", "10 free saves", "your original is never modified"), placed at the moment it becomes relevant — consent before first upload, deletion line on the result screen — never as a generic "we value your privacy" paragraph and never as a badge wall on Home.

### 2.3 The consent moment

- **[Requirements]** S2 consent sheet is shown once per `consent_version`, before the first upload only, blocks upload until accepted, is never pre-ticked and never bundled with Terms acceptance. Exact wording is fixed in §11.2A. Declining costs nothing and returns the user to Home.
- **[Inference]** This is structurally the right pattern — one decision, at the moment of consequence, in a sheet (not a full screen, so Home remains visibly behind it). The design risk is not placement but *density*: the verbatim copy plus two buttons plus a Privacy Policy link must fit a small Android screen without scrolling at 1.30 text scale. That constraint is carried into DESIGN_DIRECTION.md as a layout test, not solved by shrinking type.

---

## 3. Photo pick → processing: the wait is the product

PeopleGone is the only app in this set whose core work happens server-side over seconds-to-minutes (NFR-01: warm median ≤ 20s end-to-end, p95 ≤ 45s incl. cold start; analysis ≤ 5s warm). Every competitor below processes on-device or near-instantly, which makes their wait UX *less* instructive than their failure to need one. The patterns that transfer are about honesty of state.

### 3.1 Named stages beat spinners

- **[Requirements]** S3 splits Uploading (determinate %, from the actual upload) from Analysing ("Finding people…", indeterminate). S6 reports per-person progress ("Removing person 2 of 4…"), is cancellable, never freezes the UI, and survives backgrounding via polling on resume (§4.2, §6.7). A spinner with no state is explicitly called out as the failure mode (UF-17).
- **[Verified pattern]** General AI-image-tool front-end practice, documented in recent UX write-ups on honest progress: keep *dispatch*, *acceptance*, and *completion* as separate states; show a real percentage only where a real measurement exists (upload bytes), use indeterminate progress where duration is genuinely unknown, and never let a bar sit at ~99% on an invented curve. A calm named status outperforms a fake percentage. (§10.)
- **[Verified pattern]** Long-operation UX guidance consistently separates <10s work (spinner is tolerable) from >10s work (needs percent-done or a time expectation). PeopleGone's 20–45s band sits squarely in the second class — hence per-person counts and stage names, not a lone spinner.
- **[Inference]** The per-person progress in S6 is not decoration: it is the only truthful determinate signal the pipeline has (crops complete one by one, §6.4 Stage B step 3–4). Design must therefore treat "person N of M" as the primary progress element and resist any additional fake granularity (no elapsed-time predictions, no percentage derived from elapsed time).

### 3.2 Cancellable, resumable, never lost

- **[Requirements]** Jobs are idempotent (one ID per photo hash + settings), retries poll the same job before creating a new one, a completed result stays downloadable for 24h, offline picks queue locally and start on reconnect, and cancelling consumes nothing (§6.7, FR-07, FR-11).
- **[Verified pattern]** Mature image-workflow engineering write-ups make the same state model explicit — `queued / processing / review / succeeded / failed` as distinct states, retries reusing the saved job definition so a network failure never forces the user to reconstruct their work, and provider error codes kept internal while the user sees one actionable message. (§10.)
- **[Inference]** The UX consequence: there is no "dead" state in PeopleGone. Every wait and every failure must render as one of: still working (named stage), queued (offline or busy copy per §6.7/§8.2), done-but-not-yet-viewed, or failed-with-one-retry-action. A generic error screen with only "OK" would break the model the backend already guarantees.

### 3.3 What competitors do instead — and why it doesn't transfer

- **[Verified pattern] Apple Clean Up** processes on-device in seconds; its "wait" is a brief shimmer on the brushed region. **[Verified pattern] SnapEdit** reports processing "usually finishes in a few seconds" and shows minimal progress chrome. **[Verified pattern] TouchRetouch** removal is effectively instant after tapping Go, with a fade transition masking the computation.
- **[Inference]** None of these apps has had to design for a 45-second cold start, so there is no incumbent pattern to copy for S6 — this screen is PeopleGone's most original design surface and its highest-risk one. It must be designed from the honesty principles above (§3.1), not by imitating a competitor's near-instant feedback. It is flagged as such in DESIGN_DIRECTION.md.

---

## 4. Before / after comparison

This is the most convergent pattern in the entire set — every product implements it, in one of exactly two forms:

- **[Verified pattern] Hold-to-view-original.** Google Photos: tap-and-hold on the edited image shows the original; release returns to the edit. Used in the editor and in the share-sheet quick-edit compare. Snapseed: a dedicated before/after toggle users are coached to check constantly ("always toggle before/after to check your progress" is standard guidance for its tools). People's muscle memory on Android expects hold-to-compare.
- **[Verified pattern] Before/after slider.** Google Photos' redesigned editor adds an explicit before/after comparison button alongside the slider-based tools; Lightroom presents before/after as side-by-side states and a toggle in its edit flow.
- **[Requirements]** S7 mandates *both*: hold-to-view-original **and** a before/after slider (FR-13, UF-14).
- **[Inference]** Shipping both is correct and not redundant: hold-to-compare is the fast judgement ("did it work?"), the slider is the inspection tool ("is that edge clean?") used at 100% zoom on the exact region that was inpainted. The design must make the two gestures non-conflicting: hold anywhere = original while held; the slider is a distinct, visibly-handled control that only exists in compare mode. Details in DESIGN_DIRECTION.md §S7.

A second convergent detail:

- **[Verified pattern] Save as copy, original untouched.** Google Photos' quick-edit flow saves the enhanced result as a copy; Apple edits are non-destructive with Revert to Original always available from the edits menu; Lightroom and Snapseed both keep an editable, revertible stack.
- **[Requirements]** PeopleGone saves a copy, never modifies the original, files land in on-device history (FR-14, FR-18, S9). There is no edit stack — the result *is* the deliverable.
- **[Inference]** Because there is no stack to revert through, PeopleGone's equivalent safety affordances are per-person undo on the result (FR-10) and Brush fix (FR-09). They must be visually as available as Apple's Revert — present on S7 without entering a menu — or users will read a flawed result as final and rate accordingly.

---

## 5. Keeper proposal / confirmation screens — the defining screen

S4 (Proposal) has no exact equivalent in any competitor. It is a hybrid of two patterns:

### 5.1 Auto-detection with tap-to-toggle (SnapEdit's pattern)

- **[Verified pattern] SnapEdit (Auto mode):** on photo open, the AI outlines every detected object and person; the user taps each item to select or deselect it, or uses Select All; one Erase button removes the selection; processing takes seconds; missed details fall back to brush with Auto Detect toggled off. (§10, SnapEdit's own guide.)
- **[Verified pattern — the gap]** SnapEdit detects *objects in general* and has **no main-subject protection** (Requirements §1.2). Nothing in its flow distinguishes "your family" from "strangers". Its selection is a list of equals.
- **[Requirements]** PeopleGone S4 inverts the default: every background person is pre-marked REMOVE (red), the main subject is pre-marked KEEP (green) and is *never* in the default remove set (FR-04); low subject-confidence defaults to KEEP with a warning; tapping any person toggles; the primary button counts live ("Remove N people"); an overlap with the subject triggers a one-line quality-risk note.

### 5.2 Suggested-removal highlighting (Apple's pattern)

- **[Verified pattern] Apple Clean Up:** when the tool opens, items the system thinks you want gone are automatically highlighted with a fluorescent/luminescent glow; tapping a highlighted item removes it. Anything not highlighted is handled manually (tap / brush / circle). Pinch to zoom and pan for precision.
- **[Inference]** Apple proves users accept — and like — acting on machine suggestions when (a) the suggestion is visually obvious, (b) acting on it is one tap, and (c) ignoring it costs nothing. PeopleGone S4 satisfies all three, but with higher stakes: Apple's suggestions are opt-in per item (nothing is removed until tapped), whereas PeopleGone pre-selects removals and asks for one confirming tap. That inversion is the product's whole promise ("one tap"), so the visual language must carry more certainty than Apple's glow: full-instance masks (not outlines), a persistent colour legend in words, and the keeper rendered as visibly *protected*, not merely unselected.

### 5.3 Colour semantics are already a shelf convention

- **[Verified pattern] TouchRetouch** paints the removal mask **green** while brushing (with a red variant reported in other versions/flows); SnapEdit's brush marks in red. There is no cross-app standard for "this colour = remove".
- **[Requirements]** PeopleGone's convention is fixed in the conventions doc: `overlayRemoved` red (#E5484D family), `overlayKept` green (#30A46C family), both at 55% fill with a solid stroke, in light and dark palettes.
- **[Inference]** Because the shelf has no standard, PeopleGone's colours must never be asked to work alone: every mask state also needs a non-colour signal (the live count on the button, a Keep/Remove label on tap/selected state, and TalkBack announcements). This is also an accessibility requirement — red/green is the single worst pair to rely on for colour-vision-deficient users (§8). The palette values stay as specified; the *redundancy* is the design work.

### 5.4 The "no people / only subject" outcomes

- **[Requirements]** If analysis finds no background people, or only the subject: a plain spoken message ("There's nobody in the background to remove") plus an offer of Brush mode; no credit is ever consumed for an empty job (FR-06, S4).
- **[Inference]** No competitor studied has an equivalent state, because general editors always have something else to sell you on that screen. In PeopleGone this state is a trust asset — the app declining to take your money/work when there is nothing to do. It should be designed as a calm, complete end-state, not an error.

---

## 6. Brush / manual rescue

PeopleGone's Brush (S5) is a *rescue* tool, not the primary flow (FR-09, §2.1 item 5). The brush-first apps show both what to copy and what to avoid:

- **[Verified pattern] TouchRetouch brush kit:** Brush and Lasso for marking, Eraser for refining the mark, brush/eraser size in a Settings control, **a loupe/magnifier that shows exactly what's under your finger**, multiple items markable before one Go tap, unlimited undo/redo, and a fade transition as the removed area is replaced. Tutorials exist per tool.
- **[Verified pattern] Apple Clean Up brush:** brush size is adjustable (explicitly on macOS; pinch-zoom is the precision method on iOS), and brushing over a face triggers a protective pixelation behaviour rather than removal.
- **[Requirements — deliberate divergence]** PeopleGone FR-12 forbids the face-pixelation fallback entirely: removing a person removes the whole person; the app must never pixelate a face or generate a substitute face. Brush scope is also narrower: Add-to-removal / Erase-from-removal, brush-size slider, pinch-zoom, undo/redo, "Done" returns to S4 (pre-removal) or re-runs inpainting on the affected crop only (post-result, S7 Brush fix).
- **[Verified pattern — the shadow lesson] Lightroom Generative Remove:** a widely documented failure is selecting the object but not its shadow — the engine then replaces the object *and leaves/regenerates around the shadow*, in one documented case replacing a stump with a different stump because the shadow had been left out of the selection. Including the shadow in the selection fixed the result. (§10.)
- **[Requirements]** PeopleGone already designs this lesson in at the system level: removal masks include cast shadow and attached belongings by default, and the expanded mask is what's displayed (FR-08, §6.4 step 2). Reflections are *not* automatic in v1 — brush + warning only (D9, FR-09).
- **[Verified pattern — anti-pattern] Snapseed Healing:** the brush size is *not* adjustable; the documented workaround is to pinch-zoom so the fixed brush is effectively smaller. Users experience this as friction with a workaround, not a feature.
- **[Inference]** Three brush rules follow for PeopleGone: (1) brush size must be a visible slider on the brush screen itself (TouchRetouch/Snapseed lesson — never buried, never absent); (2) an offset loupe or offset brush preview is required, because on a phone the finger occludes exactly the mask edge the user is trying to place (TouchRetouch's loupe is the proven solution); (3) the brush screen must show the *shadow-inclusive* mask as the starting state, so the user edits the real mask the pipeline will use, not a tighter fiction (Lightroom lesson).

---

## 7. Paywall placement and pricing honesty

### 7.1 The incumbent patterns

- **[Verified pattern] Google:** the generative editor's free allowance is counted in *saves* (10/month for non-Pixel/non-Premium users — Requirements §1.2), not in previews or attempts. The user can perform the edit, judge the result, and the meter runs only on keeping it.
- **[Requirements]** PeopleGone adopts the identical mechanic deliberately: previews unlimited and watermark-free, the **save** consumes 1 free save, retries/re-runs of the same photo never consume, identical-photo cache hits consume nothing (§9.1, FR-11, FR-16).
- **[Verified pattern] RevenueCat's published paywall guidance** (the billing vendor PeopleGone ships, §6.1): show the paywall at natural conversion points, not on launch; always include Restore Purchases; fetch prices from the store offering, never hard-code; state the full billed amount, period, and cancellation path; for freemium, paywalls should be contextual prompts the user can dismiss rather than blocks on free content. (§10.)
- **[Requirements]** PeopleGone S8 is stricter than the generic guidance: it appears *only* when Save is tapped with 0 free saves and no Pro, or when deliberately opened from Home badge/Settings; never before the user has seen a first successful result; it shows the user's own result preview **unblurred and unwatermarked**, all three plans above the fold with Annual pre-selected and Lifetime equally visible, plain-language renewal terms, Restore Purchases, and a working "Not now" under which the result remains available for 24h (§9.3, S8).

### 7.2 The anti-patterns (all verified on this shelf)

- Blurred/watermarked result held hostage behind the paywall (SnapEdit free tier: watermark + 1,600px cap; Cleanup.pictures free: 720px exports).
- Limits discovered at export rather than stated before work begins (Requirements UF-08…UF-12).
- Weekly SKUs and trial traps (Requirements §9.2: no weekly SKU ever; no store free trial at launch — the 10 free saves *are* the trial).
- Licence/plan changes sprung on existing buyers (TouchRetouch backlash; countered by Requirements §9.3 grandfathering: a Lifetime buyer can never be moved to a subscription).

- **[Inference]** PeopleGone's paywall is therefore designed as a *receipt for value already received* — the cleaned photo sits at the top, finished and visible — rather than a gate in front of unseen value. The design consequence is that S8's hero is the user's own photo, not an illustration, a feature list, or a discount badge. Any design that leads with price, countdown, or plan chrome over the photo itself contradicts the mechanic.

### 7.3 The counter is part of the paywall system

- **[Requirements]** The remaining-saves counter is visible from Home onward (FR-25), on Home (S1) and in Settings (S10), and the server ledger — not the on-device number — is the truth (FR-20).
- **[Inference]** Because the counter is always visible, S8 should never be a surprise and must not be designed as one (no "You've run out!" alarm framing). Its tone is bookkeeping, not emergency: "That was your last free save this month" is the register. This is a deliberate tonal divergence from category norms and is locked in DESIGN_DIRECTION.md.

---

## 8. Error, retry, and empty states

- **[Requirements]** Global rules (§4.3): loading always names its stage; errors are plain-language with exactly one recovery action (Retry / Pick another photo / Go Home), technical codes go to logs only; every list has an empty state teaching the one job in one line; oversize input (>100MP/60MB) is an explicit error, never a silent downscale; dark mode follows system; rotation supported for photo viewing.
- **[Verified pattern]** The state taxonomy from image-workflow practice (§3.2) maps 1:1 onto PeopleGone's job model, including the subtle one: a *timed-out client* does not mean a failed job — on Retry the app polls the same job ID first (§6.7). The UI must therefore distinguish "we lost contact" from "the job failed"; they have different copy and different primary actions.
- **[Verified pattern — ghost honesty] Requirements §6.4 step 5 / S7:** if the second-pass check suspects a leftover ghost/shadow, the result screen *says so* and offers "Try fix" — the app never silently delivers a suspected ghost. No competitor studied surfaces its own quality doubt this way.
- **[Inference]** Error design rule that follows: PeopleGone errors fall into exactly four user-visible classes, each with fixed copy shape — (1) *your connection* (queued/retry), (2) *this photo* (too large, unreadable — pick another), (3) *our servers are busy* (queued, honest copy from §8.2 — never mention cost/abuse), (4) *this result may have a flaw* (ghost notice + Try fix). Anything that doesn't fit these four is a bug in the error taxonomy, not a new message.

**Empty states inventory (all [Requirements]-mandated):** Home with no history (one line + Pick button); History empty (same teaching line — S9); Proposal with no background people (message + Brush offer, §5.4); Settings has no empty state. No other lists exist in v1.

---

## 9. Navigation, density, dark/light, accessibility

### 9.1 Navigation: there is barely any, and that's the point

- **[Verified pattern]** General editors need real navigation: Snapseed 3.0 organises into Looks / Faves / Tools tabs plus a home grid; Lightroom carries a full bottom toolbar of tool categories; Google Photos' editor buries removal inside a general Edit stack. In each case, removal is *one tool among many*, reached through at least two levels.
- **[Requirements]** PeopleGone has no tab bar, no drawer, no tool grid. Navigation is a single linear flow (Home → … → Result → Home) with two lateral exits: History (a grid on/part of Home per S1/S9) and Settings (icon from Home). Screens S1–S10 are the whole app.
- **[Inference]** This is the strongest structural differentiator PeopleGone has and design must protect it: any proposal to add a home-screen tool grid, a "Discover more features" row, or a bottom tab bar is scope invention, not design. SnapEdit's home — a grid of unrelated AI tools (background removal, enhance, skin, text) — is the documented example of the shape PeopleGone must not drift into.

### 9.2 Density

- **[Verified pattern]** Lightroom mobile is the density ceiling: layered toolbars, mode toggles (object-aware vs generative), per-tool options. It serves users who identify as editors. Snapseed's density is lower but its signature gesture (swipe anywhere to adjust values, with a dial in 3.0) trades discoverability for space — new users routinely need a tutorial to learn that swiping is the control.
- **[Requirements]** PeopleGone's target user is a non-editor (tourists, families — §1.4) on mid-range/older Android phones, including 3GB-RAM devices (NFR-03).
- **[Inference]** Density rule: one primary action per screen, visible controls for everything (no gesture-only controls anywhere in the golden flow — gestures *enhance* (pinch, hold) but never *gate*), and no control that requires the user to know a term like "mask", "inpaint", or "instance". The proposal screen's vocabulary ceiling is "people", "keep", "remove".

### 9.3 Dark / light

- **[Requirements]** Dark mode follows system (`ThemeMode.system`), no in-app toggle in v1 (Conventions §6.1); both palettes are fully specified, including dark variants of the proposal overlays.
- **[Verified pattern]** Material 3 guidance: support both themes via semantic colour roles and tonal surfaces rather than shadows in dark mode; never hard-code black/white. PeopleGone's token system already implements roles (`surface`, `background`, `textPrimary`…) rather than raw colours in feature code (Conventions §6).
- **[Inference]** Photo screens are a special case in both themes: the photo itself is the brightest/darkest element on screen and changes per image. Chrome around the photo (S4–S7) must therefore be legible *against the photo*, not just against the scaffold background — this argues for the scrim-backed control treatment specified in DESIGN_DIRECTION.md, in both themes equally.

### 9.4 Accessibility

- **[Verified pattern] Material / platform baselines:** minimum 48×48dp touch targets, normal-text contrast ≥ 4.5:1, content descriptions on icon-only controls, TalkBack testing, colour never as the sole signal (a status must also carry text/icon/border differentiation). (§10.)
- **[Requirements]** PeopleGone already bakes in: 48dp minimum targets (Conventions §6.3), text scaling honoured via system setting clamped to 0.85–1.30 so layouts survive large-text users (Conventions §6.4), bundled fonts with legibility chosen deliberately (Inter), minimum body size 13sp (`bodySm` floor).
- **[Inference — the three PeopleGone-specific a11y risks]**
  1. **Red/green proposal masks** (§5.3): the most common colour-vision deficiency hits exactly this pair. Needs redundant encoding.
  2. **Gesture-only compare** (hold + slider on S7): needs a non-gesture equivalent (a labelled Before/After toggle control) for switch-access and motor-impaired users.
  3. **Long waits** (S3/S6): progress must be announced (live-region semantics: stage changes and completion) or a TalkBack user gets silence for 45 seconds. None of the three is addressed by the generic baseline; all three are specified in DESIGN_DIRECTION.md.

---

## 10. Sources

Product behaviour and patterns (accessed 2026-10-13; paraphrased, not reproduced):

- Apple Clean Up — hands-on and support coverage: PopSci, *3 useful ways AI can improve your photos in iOS 27* — https://www.popsci.com/diy/three-useful-ways-ai-can-improve-your-photos-in-ios-27-tech-tips/ ; Gadget Hacks, *Remove Objects, People, and Distractions in Photos with Clean Up* — https://apple.gadgethacks.com/how-to/remove-unwanted-objects-people-and-distractions-photos-your-iphone-ipad-mac-0385645/ ; MacRumors, *iOS 18.1: Remove Unwanted Objects From Your Photos* — https://www.macrumors.com/how-to/ios-use-clean-up-tool-photos/ ; MacObserver Clean Up guides — https://www.macobserver.com/ios/photos-clean-up-tool-remove-background-objects/
- Google Photos editor — Android Authority, *Google Photos will soon suggest advanced edits with a single tap* (tap/brush/circle → suggested edits; before/after button) — https://www.androidauthority.com/google-photos-new-image-editor-3565829/ ; Android Police, *Google Photos could make photo enhancements less of a pain* (hold-to-compare in share quick-edit; save as copy) — https://Www.Androidpolice.com/google-photos-enhance-shared-images/
- TouchRetouch — Mobiography, *How to Use TouchRetouch App to Remove Objects from Photos* (brush/lasso/eraser, loupe, Go button) — https://www.mobiography.net/apps/touchretouch-app/ ; iPhone Photography School, *How To Use TouchRetouch App* (brush size via Settings, undo vs eraser, Export flow) — https://iphonephotographyschool.com/touchretouch/ ; SlashGear, *5 Apps For Removing Unwanted Objects In Your Photos* (per-tool tutorials, dedicated line/mesh tools) — http://slashgear.com/1627647/apps-to-remove-unwanted-objects-from-photos/
- SnapEdit — SnapEdit's own guide, *How to Remove Objects and People from Photos with SnapEdit* (Auto Detect outlines, tap select/deselect, Select All, Erase, brush fallback, shadow-in-selection tip) — https://snapedit.app/blog/how-to-remove-object-with-snapedit
- Lightroom Generative Remove — TechNave, *Quick and easy edits on the palm of your hand with Adobe Lightroom mobile* (eraser-icon entry, tap flow, redo with Generative AI) — https://technave.com/gadget/Quick-and-easy-edits-on-the-palm-of-your-hand-with-the-Adobe-Lightroom-mobile-app-39479.html ; Jim Babbage, *Using Generative Remove in Lightroom* (shadow-exclusion failure and fix; per-object vs batch selections) — https://jimbabbage.photography/using-generative-remove-in-adobe-lightroom
- Snapseed 3.0 — Android Police, *Google is bringing the Snapseed redesign to Android* (home grid + FAB picker, Looks/Faves/Tools tabs) — https://Www.Androidpolice.com/google-is-bringing-the-snapseed-redesign-to-android/ ; Tom's Guide, *How to use Snapseed* (Healing via pinch-zoom + brush/tap; checkmark/X commit) — https://www.tomsguide.com/ai/chatgpt/snapseed-is-the-best-photo-photo-editing-app-youre-probably-not-using-and-its-free
- Paywalls — RevenueCat blog, *R.I.P. toggle paywall* (multi-package selector, price anchoring, value-first, trust over tricks) — https://www.revenuecat.com/blog/growth/rip-toggle-paywall ; RevenueCat paywall best-practice references (restore button, natural conversion points, store-fetched prices, dismissal respect) — https://github.com/noloman/android-ai-skills/blob/HEAD/revenuecat-best-practices/references/paywalls.md
- Honest progress / job states — *Front-End Patterns for Honest Progress in AI Image Tools* (separate dispatch/acceptance/completion; percentages only from real measurements) — https://viblo.asia/p/front-end-patterns-for-honest-progress-in-ai-image-tools-XP4WEZlpL7G ; Fireart, *How to Make App Load Times Feel Faster* (spinner ≤ ~10s; percent-done/expectation beyond) — https://fireart.studio/blog/4-tricks-to-make-load-times-feel-faster/ ; *How to Build a Testable Image Editing Workflow* (explicit job states; retries reuse the job; internal vs user-facing errors) — http://dev.to/bolg/how-to-build-a-testable-image-editing-workflow-for-web-applications-11hf
- Accessibility / Material baselines — Material 3 / Android accessibility compliance references (48dp targets, 4.5:1 contrast, colour-never-sole-signal, TalkBack checks) — https://github.com/comp90018-2025-sm2-t4-g2-android/comp90018-t4-g2-mobile-app/blob/HEAD/docs/Material3_Compliance.md
- Ratings, caps, pricing, and all competitor facts marked [Requirements] — `PEOPLEGONE_REQUIREMENTS.md` §1.2, §9, §15.2 (verified there 2026-10-12) and `research/competitors.md`, `research/user-feedback.md`.

---

## 11. Open questions this research raises for the owner

Carried into DESIGN_DIRECTION.md §9 (not decided silently there):

1. **S6 wait experience:** when a job runs long (cold start ~45s), may the user leave the screen and be notified on completion, or must S6 hold them? The backend supports backgrounding/polling; the *design* choice (notification? Home badge?) is unspecified in the requirements.
2. **Proposal legend wording:** the requirements fix the *colours* but not the on-screen legend copy for Keep/Remove. Proposed copy is in DESIGN_DIRECTION.md for approval — it becomes a strings entry, so it needs owner sign-off like other copy.
3. **History placement:** S1 says Home shows the history grid; S9 specifies History as its own screen spec. Is History a section of Home, a separate route from a Home header action, or both? Affects navigation spec.
4. **First-result celebration:** nothing in the requirements authorises (or forbids) any success moment after the first save. Default in the direction doc is *none* — confirm.

