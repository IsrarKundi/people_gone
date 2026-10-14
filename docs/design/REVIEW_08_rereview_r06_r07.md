# Review 08 — Re-review: Review 06 Fixes + S5 Brush (B1–B6)

**Date:** 2026-10-14
**Reviewer:** UI/UX design lead
**Material:** Commits `32a92bb` + `26c07dc` (Review 06 fixes), `12c2473` + `e3ef4d3` + `d6b62da` (Review 07 rebuild + evidence), judged from the regenerated harness renders — S6 light/dark; S5 hint, painting (light/dark/portrait/1.30), fixing (light/dark) — and the strings/code for the banner. **Design review, not launch approval.**

**Verdicts: Review 06 round CLOSED (F1 + F2 confirmed). S5 Brush — APPROVED (B1–B6 all confirmed).** Two review rounds close in one pass; what remains open in the project is listed in §4 and none of it is in these two screens.

---

## 1. Review 06 fixes — CONFIRMED

- **F1 (S6 frame hugs the photo):** the frame now fits the café photo's aspect exactly, in light and dark — a framed print centred on the canvas, spare space on the canvas *outside* the frame, tray untouched below. The bordered void is gone. D13 is satisfied as written.
- **F2 (failed banner):** subtitle is now "No save was used" (verified in strings), the tap dismisses, and diagnostics lives only on the error view and in Settings. The failed state now gives the user their fact and an exit — the two things it owed them.

## 2. S5 Brush — B1–B6 CONFIRMED, screen APPROVED

- **B1 (canvas):** the photo is fitted and centred as a work surface — the landscape café photo as a band, the owner's portrait mosque photo filling the canvas. First evidence of the portrait case (the one that broke W1's predecessor) is clean.
- **B2 (hint):** the chip sits *inside the fitted rect's top edge*, sized to its content — wide only because the settled hint text is long — in photoChrome, and it is **gone in every capture with strokes** (painting, portrait, fixing): it retires after the first stroke, as ruled. W1 and W4 are closed by the same evidence.
- **B3 (footprint dot):** present at the size row's end in every state, in the mask colour, tracking the slider's slot. The calibration instrument W5 required exists.
- **B4 (fixing in the dock):** this is the transformation the round was about, and it is complete. No floating box; the canvas keeps the painted stroke in view; the determinate bar runs along the dock's top edge at a real 45% upload; and the primary — the button that used to collapse into a blank pale slab — is the filled button, spinner + "Fixing…" label intact. The labelled-loading mode added to PrimaryButton (`e3ef4d3`) fixes the slab pattern *systemically*: no button in this app should ever again render as an anonymous pale rectangle while it works.
- **B5 (painting state):** primary disabled-with-visible-state before strokes (hint capture), filled "Remove painted area" with strokes (painting captures); Undo/Clear gate on strokes exactly as before.
- **B6 + D15 (themes, scale, exit):** dark painting and dark fixing both PASS (dock, slider, dot, and primary all legible; the dark fixing bar reads clearly). 1.30 painting PASSES — dock rows hold, the slider stays usable, no label truncates. And in both fixing captures, with every editing control disabled, **Cancel is lit** — the exit never disables, as D15 now requires.
- **One mechanics correction, recorded for accuracy:** my B4 assumed a cancelled fix would ride a refund path. The implementation is cleaner than my assumption — a touch-up consumes no save at fix time (consumption happens when the touched-up *result* is saved from S7), so a mid-fix cancel has nothing to refund and simply drops the result. The ruling's intent (a user is never charged for an abandoned fix) is satisfied by construction. Noted so the record describes the system as it is.

*On the canvas air around a landscape photo:* it is not a D10 terminal void — the screen is anchored (title above, dock below) and the middle is a work surface, with the photo as large as contain allows. D10 governs content screens; an editor's canvas is a surface, and this one is composed.

## 3. What this closes

Review 05 (Home/Processing) — closed in Review 06. Review 06 — closed here. Review 07 (S5) — closed here, with S5 approved at first re-review. The design system gained two durable assets in this round: PrimaryButton's labelled loading, and the D14/D15 rules that produced it.

## 4. Still open (unchanged, none of it in S5/S6/Home)

S4 re-review **in the real flow** (the Task D wiring + Review 04 F3–F6 — the largest remaining design debt); TalkBack passes (S4/S5/S6/S7); S2 consent at 360×640 (pinned actions); G3 ghost notice (waits on the API flag); S8 Paywall review when Phase 3 builds it.
