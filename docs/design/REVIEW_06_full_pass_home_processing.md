# Review 06 — Full Pass: Home + Processing as Implemented

**Date:** 2026-10-14
**Reviewer:** UI/UX design lead
**Material:** The landed implementation — feat-05 (`f50f654`) plus the design-r05 commits (`da1cd7a` Processing, `4eb728b` Home) on origin/main at `4eb728b` — judged from the regenerated harness renders (light + dark, first-run + with-history, 1.30 text scale) and from the view/controller code for everything a still cannot show (stage-label logic, banner state copy, Cancel's dialog). This closes the evidence list owed since Review 05 §3. **Design review, not launch approval.**

**Verdicts: Home — APPROVED. Processing — APPROVED WITH ONE REQUIRED FIX (F1, the photo frame). One further required fix on the banner's failed state (F2).** The Review 05 round is otherwise closed: every R-ruling and both factual fixes are implemented and verified below. What the redesign promised on the owner's screenshots, the code now actually does — including the parts screenshots couldn't prove.

---

## 1. Home — APPROVED (all states evidenced)

- **First-run, light:** the composition now completes. The hero slot runs to the bottom edge; the quota is a plain text line in the column ("10 of 10 free saves left · Resets 1 Nov" — no pill, no dot, R5); the teaching line is body size, an introduction rather than a headline (R4); the caption is provenance only ("Real app output", R9). (The harness's light capture shows the demo image undecoded — a known fixture artifact on this machine; the dark and 1.30 captures and the owner's device render the card correctly, and I do not hold a harness artifact against the build.)
- **Dark:** PASS. The demo fills its tall slot (cover), labels sit on the photo, the caption strip belongs to the card, the primary stays legible with dark text on the light-blue dark-theme primary.
- **1.30 text scale:** PASS. The teaching line wraps to three lines with clean breaks, the quota stays on one line, nothing truncates or breaks mid-word.
- **With-history hero (first real evidence):** PASS. This state did not exist as evidence before this pass, and it is well composed: the latest clean leads as a framed card (photo, "Cleaned" badge, date, "Tap to compare"), earlier cleans sit in a horizontal tray whose cut-off fourth item correctly signals scrolling, the teaching line is rightly absent, and "History / See all" leads to S9's grid — the D7 arrangement working as designed. The screen composes to its bottom edge (D10 satisfied).
- **Job banner (code-verified; the card is shared across states):** one card language — neutral hairline, shared radius, state colour carried by the icon only (D12, and the code says so). Processing state: "Cleaning photo in background…" / **"Tap to view progress"** (F2 and R10 closed — destination only). Done state: "Your cleaned photo is ready" / "Tap to view and save your photo" — factual, and the tap opens the Result. **Failed state: see F2 below.**

## 2. Processing — APPROVED with F1

Everything Review 05 demanded of this screen's *structure and text* is present and verified:

- **Tray, in flow, bottom-anchored** (R1): photo, status card, filled primary, caption, Cancel — stacked, no overlaps anywhere (R2 closed). The ghost pill is gone; "Work in background" is now the filled primary it always should have been (R6), with "You can safely leave the app." captioning it directly (R7).
- **Stage labels follow real states (Review 05 F1 — CLOSED, code-verified):** the title logic is exactly the rule I set — "Connecting to the processing server…" while no bytes have moved; "Uploading your photo… N%" only while bytes transfer, with the determinate bar rendered *only* in that same condition; the server stage shows "Finding people and removing them…" with expectation and **no bar, no %, no clock**. The captures show the server stage behaving exactly so.
- **Stopwatch removed** (D11a) — the card is now stage + expectation, nothing else.
- **Dark:** PASS (same structure, legible throughout). **1.30:** PASS (status and expectation wrap cleanly; Cancel survives at the bottom).
- **Cancel:** bare text on the plain canvas, as ruled; its confirm dialog is verified in code — "Cancel this clean?" / "Nothing will be charged to your free saves." / "Cancel clean". The no-charge fact is stated before the user commits, which was the owed check from Review 05 §3.
- **Beam:** visibly dosed down in the captures — a faint line crossing the photo band, no longer the loudest object on the screen (R8). Its indeterminate-only sanction continues, as does its status as the least-evidenced element (supplement, research grounding §3).

**F1 (REQUIRED) — the photo frame must hug the photo.** The frame is a fixed tall card and the photo is contained inside it, so a landscape photo sits as a band stranded mid-frame with unstructured surface above and below *inside the card* — in light, dark and 1.30 captures alike. The terminal void was not eliminated on this screen; it was given a border and moved indoors. Fix: the frame's height follows the photo's aspect (within sensible min/max bounds); the spare space then falls between frame and tray, on the canvas, where it reads as gallery air. Portrait photos (the owner's mosque shot) are unaffected — their frames already hug.

## 3. The letterbox ruling (asked for explicitly)

**User photos are never cropped in this app. Contain is the only honest fit for user content** — a hero or result that cropped the user's cleaned photo would misrepresent the very thing the app sells. Cover is reserved for app-owned samples, and the demo card uses it correctly (its labels sit on the photo; the pair still demonstrates the removal truthfully). So contain is not the defect. **The fixed tall frame is.** The distinction that governs both this fix and the with-history hero: a *composite* card (photo + badge + date + action, like the history hero) may hold a photo band — its furniture makes the card a designed object; a *pure photo frame* (Processing) has one job, presenting the photo, and must fit it. Recorded as D13.

*Minor, attached to F1:* the with-history hero's internal top band is deeper than its composition needs; when the frame fix lands, tighten the hero card's photo area the same way if it can be done without disturbing its footer. Not a condition of approval.

## 4. F2 (REQUIRED) — the banner's failed state speaks to the wrong audience

Verified in code: failed title "Clean could not be completed" is fine. Its subtitle — "Tap to share diagnostics" — makes a developer debugging action the *only* thing a normal user is offered at the exact moment their clean failed, and nowhere does the state give the user their fact: **that no save was used.** My Review 05 §3 criteria for this state were explicit: it must read as a state with the no-charge fact, never a dead end. Fix: the subtitle states the fact (e.g. "No save was used") and the tap dismisses or returns the user to their photo; diagnostics sharing already lives where it belongs — on the processing error view and in Settings. (Done/processing states are unaffected.)

## 5. State of the Review 05 round

Closed: R1–R10, F1 (stage labels), F2 (banner wording), D10/D11/D12 as implemented. Open after this review: **F1 (frame hugs photo)** and **F2 (failed banner)** above — both small, both bounded. Still owed from earlier rounds and unchanged: S4 re-review in the real flow, S5 Brush first review, TalkBack passes, S2 consent at 360×640, S8 paywall when built.

## 6. Direction amendment

- **D13 — Frames hug photos:** user photos are always shown whole (contain) and never cropped; a pure photo frame fits the photo's aspect, with spare space falling on the canvas outside the frame. Cover-cropping is reserved for app-owned sample imagery (the Home demo). Composite cards (photo + metadata + action) may hold a photo band.
