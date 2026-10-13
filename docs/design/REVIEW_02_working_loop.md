# Review 02 — The Working Loop (Home / Processing / Result / Settings / History)

**Date:** 2026-10-13 (late)
**Reviewer:** UI/UX design lead
**Material reviewed:** Six owner-run screenshots, iOS Simulator (iPhone 11 Pro Max), light mode, from the owner's own end-to-end run of the full loop on 2026-10-13 (23:49–23:52 PKT): S1 first-run, S6 Processing, S7 Result, S10 Settings with the photo-handling sheet open, S9 History item detail, S1 after one save. Spot-verified against the code in this repo (`processing_view.dart`, `result_view.dart` / `compare_slider.dart` / `keeper_sheet.dart`, `app_strings.dart`) where a still image cannot prove behaviour.
**Pending evidence (noted, not blocking):** dark mode and 1.30 text-scale sets — still outstanding from Review 01; required before any store build.
**Overall verdict: APPROVE WITH REQUIRED FIXES.** The loop screens are honest, calm, and minimal — they pass the owner's north star (*intuitive, easy to understand and use, modern minimal UI*) in register and structure. No screen is template slop; no copy lies. The required fixes are small and listed per screen. Separately, three **capability gaps** (not screen defects) are recorded in §7 of this review — the largest being that the defining screen, S4 Proposal, does not exist in this build yet.

Checklist references below are to DESIGN_DIRECTION §8, in order (Identity 1–5, Structure 6–11, Defining screens 12–15, States 16–20, Taste 21–22).

---

## S1 — Home, first run (23.49.02) — **APPROVE**

Review 01's rulings are fully applied: wordmark once, left-aligned, Inter 800 register, settings gear at the right (Structure 10 ✓); single top-anchored column on token gaps, no floating content (Structure 11 ✓); saves indicator with its thin bar; real "Pick a photo" primary, full-width, outcome-named (Structure 6 ✓); teaching line in flow below the button in dark primary text. No upsell, no clutter, no exclamation, no AI chrome (Identity 1–4 ✓). The empty space below the line is the approved first-run emptiness.

One deliberate deviation, **approved and folded into the direction (Amendment A1):** the teaching line is *left*-aligned, not centre-aligned as Review 01 worded it. On the built screen, left alignment wins — it sits in the column's rhythm with everything above it, and centre-aligned text in a left-aligned column was the last template habit left on this screen. The direction is amended; the builder's instinct is recorded as correct.

Minor, non-blocking: the saves line renders semibold — acceptable (it is the app's meter, and its weight matches the wordmark's register). No change required.

## S1 — Home, after one save (23.52.42) — **APPROVE**

Counter decremented truthfully (9 of 10) and the bar now shows its track at 90% — the meter reads at a glance (Identity 5 register ✓). History section appears with header + "See all" trailing action (the §9-item-3 both-surfaces decision, working), thumbnail is the actual result, rounded to token radius, date below the thumbnail in secondary text exactly as specified. This screen is the north star in miniature: one job, one button, your past work, nothing else.

## S6 — Processing (23.49.15) — **APPROVE, with required fixes F1–F2**

What a still can't show, the code proves: the progress bar is determinate **only** for upload bytes and indeterminate during processing (`value: uploading ? fraction : null`) — there is no fake percentage (§8 item 13's core demand ✓). The elapsed timer is a real measurement, and displaying it is sanctioned (Amendment A2). Cancel opens a confirm dialog whose body is the no-charge guarantee verbatim — "Nothing will be charged to your free saves." (item 13 ✓). The single stage line "Finding people and removing them…" is the honest description of Contract v1's single call; inventing separate "finding" and "removing" stages the API cannot report would have been the dishonest option, and the builder correctly refused it.

- **F1 (required): photo surround inconsistency.** On S6 the whole screen behind the letterboxed photo is a flat mid-grey; on S7 and S9-detail the same photo sits on the light background. Same photo, two screens, two surrounds — it reads as two different apps. Amendment A3 sets one rule: photo surfaces share the `background`-token surround, photo contain-fit and centred; any dim/scrim applies to the photo band only.
- **F2 (required, copy governance): expectation line.** "This can take a few minutes. Keep the app open while we work." is **approved as interim copy** — it is true of the current CPU dev worker (~2 min/photo), and a true line beats the approved-but-false "under 30 seconds" every time. Amendment A2 makes the rule explicit: expectation copy tracks measured reality per deployment. Two consequences are recorded so this interim does not harden into the product: (a) when GPU processing lands, the line reverts to the approved expectation set; (b) "Keep the app open" contradicts the requirements' resumable-job design (§6.7) and the §9-item-1 decision (completion surfaces via the Home resumable row) — that gap is in the current single-call implementation, not in this screen's honesty, and it must close at the gateway phase. The screen is not penalised for stating the implementation's truth; the implementation is on notice.

## S7 — Result (23.51.11) — **APPROVE, with required fixes F3–F4**

The strongest screen in the set. The summary line is factual and unboastful — "10 of 11 people removed. Your subject stays untouched." (Identity 3 ✓ — and the keeper in the photo is visibly untouched). The meter is stated *before* the tap — "Saving uses 1 free save · 9 left after this one" — and the location line appears on this first save exactly per the §9-item-5 decision (Identity 5, FR-15 ✓). Save/Share sit side-by-side at equal height (Structure 6 ✓). The disclosure line is verbatim with Report reachable in place, no menu (item 14 ✓). Code-verified: **both** compare modes exist — hold-to-view-original *and* the slider (`CompareSlider`, 48dp TalkBack-adjustable handle) behind the compare toggle (item 14 ✓). "Kept the wrong person?" opens a per-person kept/removed sheet (`keeper_sheet.dart`) — the FR-10 recovery, in plain words a family member understands (item 22 ✓).

**On the result photo itself:** the owner flagged the seated-crowd area on the left rendering as a smear with faint figure remnants. That is engine quality (the known large-removal weakness of the current engine), not a screen defect — and the screen neither hides it nor oversells it: the count line claims only what was removed, Save is the user's choice after judging, Report is one tap away. **But** the screen currently offers no recovery that fits *this* flaw: keeper re-run fixes a wrong keeper, Report files a complaint — neither addresses a smear. The requirements' fitted answer is the ghost notice + Try fix (§6.4 step 5) feeding Brush fix; both depend on capabilities not in this build (see G2/G3). Recorded, not held against this screen.

- **F3 (required): the top chrome.** The close and compare buttons are oversized grey discs floating in the letterbox surround *above* the photo — the weakest visual element in the whole set, and the one place the build drifts from "modern minimal". Per Amendment A3: chrome is 48dp `photoChrome` circles pinned to the photo band's top corners, on the photo.
- **F4 (required, small): disclosure wrap.** "Report this result" breaks mid-link, leaving "result" orphaned on its own line. Amendment A5: the link wraps as a whole unit or takes its own line — never a mid-link orphan.

## S10 — Settings, with the photo-handling sheet open (23.52.06) — **APPROVE, with required fix F5**

Settings itself is the specified receipt-like list: "Your plan" group, truthful counter, provider shown from config ("PeopleGone's processing servers" — no vendor name hard-coded ✓), "How your photos are handled" and Privacy Policy rows with chevrons. No icons-per-row decoration, no cards (Structure 9 ✓). Rows belonging to later phases (Manage subscription, Restore, Delete my data, licences, support, version) are absent *by phase*, recorded as pending — they are required before launch, not before this milestone.

The sheet's copy is verbatim §11.2A, fits without scrolling, policy link present in teal — the consent text survives contact with the real screen (Identity 5 ✓).

- **F5 (required): two dismiss actions.** This read-only sheet (opened from "How your photos are handled") shows a primary "Close" **and** a "Cancel" beneath it. Two ways to do the same nothing is a template artifact and a small north-star violation — a user should never have to wonder which dismiss is safe. Amendment A4: `ConsentSheet` has exactly two variants — *consent* ("Continue and upload my photo" / "Cancel", shown pre-upload) and *read-only* (single "Close"). The build's sheet shell currently leaks the consent variant's Cancel into read-only use; separate them.

## S9 — History item detail (23.52.29) — **APPROVE**

Date, full-width Share, Delete in the error colour as a text action below — the specified composition, nothing extra (Structure 6/9 ✓). Pending verifications, not defects: the Delete confirm dialog (per spec, `AppDialog` stating the original is unaffected) and the S9 grid screen itself (with its "History lives only on this phone" line) were not in this evidence set; both join the dark-mode/text-scale evidence list.

---

## Capability gaps — recorded for the owner (not screen rejects)

- **G1 — S4 Proposal does not exist in this build.** The current loop is pick → processing → result, because Contract v1 is a single call. The requirements' golden flow (§4.1) and FR-03/04/05 put a confirmation step *before* removal: see every person, keeper protected, tap to confirm. Today that judgement happens after the fact via "Kept the wrong person?". That re-run is a good recovery; it is not a substitute for confirm-before, which is the product's defining promise ("You tap once" — after seeing the proposal). **Ruling:** S4 remains required and unbuilt; it lands with the analyse/confirm API at the gateway phase, and the post-hoc keeper flow must not quietly become the permanent UX. This is the single largest open design item in the product.
- **G2 — S5 Brush / Brush fix: not built.** The result screen's repair path for leftovers and smears depends on it (requirements §2.1 item 5, FR-09). Required before MVP ships.
- **G3 — Ghost notice: not wired.** The requirements' second-pass ghost check (§6.4 step 5) and its S7 notice + Try fix have no client presence, and Contract v1 carries no ghost flag. The data model already reserves `ghost_check_fired` (§7.2) — when the API surfaces it, S7 must show the notice per spec. Until then, results like tonight's smear arrive with a success register and only Report as recourse; that is a known, named gap, not an oversight.

## Amendments folded into DESIGN_DIRECTION.md

- **A1** (§4-S1): teaching line is left-aligned to the column (supersedes Review 01's centre-aligned wording).
- **A2** (§4-S6): expectation copy tracks measured reality per deployment; elapsed-time display sanctioned; "keep the app open" class of copy is permitted only while the implementation genuinely requires it and must be removed when resumable jobs land.
- **A3** (§3 / §5 PhotoSurface): one surround rule for all photo screens — `background`-token surround, contain-fit centred photo, dim on the photo band only; on-photo chrome is 48dp `photoChrome`, pinned to the photo band's corners.
- **A4** (§4-S2/S10): `ConsentSheet` variants — consent vs read-only (single Close); dual dismiss actions are a reject.
- **A5** (§4-S7): the Report link in the disclosure line wraps as a whole unit or on its own line; mid-link orphans are a reject.
- **A6** (§4-S10): no direction change — the spec already requires the Settings counter row to carry the computed reset date ("resets 1 Nov"). The built generic "this month" line (also used there) is a build deviation to fix with the next Settings pass; recorded here so it is not lost.

**Evidence still owed before a store build:** dark mode set, 1.30 text-scale set, S9 grid screen, Delete confirm dialog, S4/S5 (when built), S8 paywall (when built). This approval covers the working loop as the development build — it is not a launch approval.
