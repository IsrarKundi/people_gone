# Review 07 — S5 Brush ("Touch up"): First Review + Redesign Rulings

**Date:** 2026-10-14
**Reviewer:** UI/UX design lead
**Commission:** Owner request — "fix this screen design too." This is also the owed S5 first review.
**Material:** The owner's screenshot of his running build (fixing state, light theme) plus the full view/controller code (`lib/features/brush/`). **No harness captures of S5 exist** — the painting state has never been rendered as evidence; where I rule on it, the ruling comes from the code, and captures are required with the fix (§4). **Design review, not launch approval.**

**Verdict: REJECTED as composed — the bones are right, the chrome is anchored to the wrong thing.** The editor's anatomy (title, canvas, bottom dock) is the category-correct shape. But both pieces of floating chrome were designed to sit *on the photo* and are positioned against the photo *area* instead, so with a landscape photo they float on empty canvas; the fixing state announces itself twice, once as a blank slab; and the screen locks its own exit during its longest wait. Rulings B1–B6 are the finished design, concrete enough to implement from.

---

## 1. What is good — keep

- **The anatomy.** Title / flexible canvas / bottom dock is how every serious mobile editor is built (TouchRetouch's tools and Go live in a bottom toolbar; Lightroom docks its controls — Review 05 research grounding). Do not redesign the skeleton.
- **The primary is outcome-named and honest about its state:** "Remove painted area", disabled-with-visible-state until something is painted — never a dead tap.
- **Undo/Clear enable only when strokes exist; the slider disables while busy.** Correct control-state discipline in the painting state.
- **The progress logic is honest:** the bar is determinate only while the upload fraction is strictly between 0 and 1, indeterminate otherwise — the S6 rule, consistently applied.
- **The mask reads well:** translucent red strokes (the app's remove colour) with the photo showing through, so the user can see the people *and their shadows* under the paint — which is exactly what the hint asks them to cover.
- **The hint copy itself** (settled, not re-litigated): it names the shadow trap, the single most common brush mistake.

## 2. What is wrong

- **W1 — Chrome anchors to the area, not the photo (the core defect).** The hint pill is positioned at the top of the photo *area*; the fixing box at the area's bottom. The photo is fitted and centred inside that area, so for a landscape photo in a tall area both chrome pieces land on blank canvas — visible in the owner's shot: a slate pill floating in white *above* the photo, a slate box floating in white *below* it. They only sit on the photo when the photo happens to fill the area (portrait). This is the photo-surround problem in its third form (after S6's surround and S7's band): **anything designed as on-photo chrome must anchor to the photo's fitted rectangle, or stop pretending to be on-photo chrome.** (→ D14)
- **W2 — The fixing state speaks twice, and the louder voice is broken.** A floating "Fixing…" box over the canvas *and* the primary button collapsed into a pale blank slab carrying only a faint spinner — no label. For the whole server round-trip (the longest wait on this screen), the biggest control on the screen looks like a rendering error, and the state it announces is already announced elsewhere.
- **W3 — The exit disables during the wait.** While busy, Cancel is disabled along with the editing controls. Undo/Clear/slider disabling is correct — the strokes are submitted. Cancel is not an editing control; it is the way out, and the way out does not get disabled because a server is thinking. (→ D15)
- **W4 — The hint is oversized for its job and outstays its welcome.** A full-width slate lozenge with small centred text reads as a banner slot, not an editor's hint; and it remains for the entire session although its work is finished the moment the first stroke lands.
- **W5 — No brush-size feedback.** The slider changes a diameter the user cannot see until they paint with it. Every serious brush editor shows the footprint (a circle at the touch point, a preview dot). Without one, users calibrate by painting test strokes and undoing them — friction on the app's most tactile screen.
- **W6 (minor) — the fixing bar's still-image reading.** The logic is honest (W-credit above), but captured mid-upload the bar reads as a static, near-full, two-tone line — the shape of a fake 97% bar. B4's relocation (dock edge, S6 rule) fixes the reading along with the placement.

## 3. The finished design — rulings

- **B1 — Canvas.** The photo is fitted (contain) and centred in the flexible canvas region on the theme background, edge-to-edge within its fitted rect (D13: for an editor, the fitted rect *is* the frame). Pinch-zoom/pan as built. No frame, no card, no radius on the photo — this is a work surface, not a presentation surface.
- **B2 — Hint.** A content-sized photoChrome chip anchored to the photo's **fitted top edge** (inside the rect, standard inset), bodySm, never full-width. It fades out when the first stroke lands and does not return for that photo. (Fallback if fitted-rect anchoring proves impractical: the hint becomes a plain left-aligned body line directly above the canvas in theme colours — no capsule. The on-photo chip is the ruling; the fallback is permitted, the floating full-width lozenge is not.)
- **B3 — Dock.** One bottom surface, as built, three rows: (1) "Brush size" + slider + **a footprint preview dot at the row's end whose diameter tracks the slider** — the calibration instrument W5 requires; (2) Undo / Clear left, Cancel right (as built); (3) the primary, full-width.
- **B4 — Fixing state (the dock transforms; the canvas stays clean).** No floating box. The primary keeps its identity and gains the state: spinner + "Fixing…" — **a loading button keeps its label**. While the fix uploads, a thin determinate bar runs along the dock's top edge (real fraction only, per the standing rule); during the server phase, indeterminate treatment only. Slider/Undo/Clear disabled; **Cancel remains enabled** (a cancelled fix behaves as a failed fix for credit purposes — refund path already exists). On success S5 returns to Result with the new photo, as built.
- **B5 — Painting state.** Primary "Remove painted area", disabled-with-visible-state until ≥1 stroke (as built). No discard confirmation on Cancel for un-applied strokes — considered and rejected: the strokes are not yet work product, the Result still holds the photo, and exit should stay frictionless.
- **B6 — Themes and scale.** No new colours: dock = surface/border, chip = photoChrome, as the code already does (the slate in the owner's shot is the token, correctly used — W4 is size and placement, not colour). At 1.30 the dock rows may stack but the slider must not be squeezed below usable width.

## 4. Evidence owed with the fix

Harness captures, none of which exist today: painting state with strokes (light + dark), fixing state (light + dark), painting at 1.30. The re-review judges from those plus a landscape *and* a portrait photo (W1 only manifests when the photo doesn't fill the area — evidence must include the case that breaks it).

## 5. Direction amendments

- **D14 — Chrome anchors to the photo, not the container:** any element designed to sit on a photo (hint chips, status boxes, badges) is positioned relative to the photo's fitted rectangle. If it cannot be, it is redesigned as off-photo chrome in theme colours.
- **D15 — The exit never disables:** during any busy/wait state, editing controls may disable; the exit (Cancel / back) remains enabled. A wait the user cannot leave is a defect, whatever the server is doing.
