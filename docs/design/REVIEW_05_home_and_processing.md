# Review 05 — New Home + New Processing (owner-screenshot pass)

**Date:** 2026-10-14
**Reviewer:** UI/UX design lead
**Material:** The owner's own two screenshots from his running build (iOS Simulator, light theme): the new Processing screen mid-job (Badshahi Mosque photo, elapsed 0:24) and the new Home with a background job running. The implementation commits are **not on origin/main yet** (main is at `780e23a`, the research doc), so this is the screenshot pass only. **This is a design review, not a launch approval — the owner's own-eyes verdict overrules it.**
**Judged against:** `HOME_AND_LOADING_RESEARCH.md` as adopted (Home Option A + Processing Option 1 + Option 3's background flow), **the owner's corrections to that research** (no "Notify me when done"; stage copy follows real states only, no clock-scripted lines, no "Almost ready"; hero demo is the cafe pair, never the arch photo; background copy is legitimate only because the banner/reattach flow ships with it), DESIGN_DIRECTION.md including §11, and the north star.

**Verdicts: Processing — APPROVE WITH ONE REQUIRED FIX (F1). Home — APPROVE WITH ONE REQUIRED FIX (F2, minor).** Both screens are a clear step forward: the theme shock is gone, the photo is the hero again, and the background-job promise is kept by a visible mechanism instead of asserted by copy. The fixes are about one label and one word.

---

## Processing (Option 1, "Living Canvas") — APPROVE with F1

**What works, specifically:**

- **Theme shock eliminated.** Porcelain canvas, photo framed as a gallery print at **natural brightness** (no dim, no darkroom), white status card. This screen finally belongs to the same app as Home — the owner's original complaint is answered.
- **The beam is approved as built.** In the still it rests at the photo's top edge as a 2dp cobalt line; in motion it is an *indeterminate* activity indicator — it claims motion, not measurement, and no copy anywhere pairs it with partial completion. That is the honest use of the motif. Standing condition: if the beam's behaviour ever changes to track position against the photo (top-to-bottom = percent), it becomes a fake progress claim and this approval lapses.
- **The backgrounding promise is kept by mechanism, not wording.** "You can safely leave the app." is on the card, and the Home screenshot (below) shows the job alive on Home with its own resumable banner — the copy and the flow ship together, which is exactly the condition the owner set. **This closes Review 02's F2 properly:** "Keep the app open" is retired not by copy edit but because the implementation changed underneath it (gateway resumable jobs + Home banner), and the elapsed timer + "~2 minutes" remain the measured truth for the CPU worker.
- **Cancel as bare text is CORRECT here — A8 is not violated.** Amendment A8 requires the photoChrome pill for text actions *on a photo surface that can land off the photo band*. In this layout Cancel sits on the plain theme canvas, below the action pill, at full contrast. A pill would be decoration, not legibility. A8 stands; this layout simply doesn't trigger it. (Tap-target height can't be judged from a still — it is on the full-pass checklist, §3.)

**F1 (REQUIRED) — the stage label does not follow the real state: "Uploading your photo... 0%" at elapsed 0:24.**
Twenty-four seconds in, the screen claims to be uploading and reports zero bytes moved. One of two things is true, and both are label failures: either bytes genuinely have not started moving (the flow is connecting, queueing, or waking a server — in which case the honest stage is that waiting state, not "Uploading"), or bytes are moving so slowly that 0% is the rounded truth — in which case the stage line and the "~2 minutes" expectation contradict each other in front of the user, and the screen reads as *stuck*, the one thing a 2-minute wait cannot afford. The owner's rule for this redesign was explicit: stage copy follows **real states only**. The upload label + % is sanctioned only while bytes are actually transferring; a pre-transfer phase needs its own factual label ("Connecting to the processing server…" / "Waiting for the processing server…" — whatever the flow is truly doing), with no percentage shown. I am not asking for new information from the server — only that the label name the phase the client is actually in, which the client knows. Fix the label logic, not the number.

*Minor, no fix required:* the status card and the "Work in background" pill both overlap the photo card's lower edge — it reads as deliberate floating chrome and the subject stays clear of it in this composition; "Work in background" (with its back arrow) is plain and does what it says. No "Notify me when done" anywhere — the owner's correction is honoured.

## Home (Option A + Option 3 banner) — APPROVE with F2 (minor)

**What works, specifically:**

- **The banner is the §9-Q1 decision, realised.** Spinner + "Cleaning photo in background..." + expectation + chevron, tappable back to the job. This is the resumable row the product specified from the start — no completion notification, no dead end, and it is what makes the Processing card's "leave the app" copy true. Its state language is factual throughout.
- **The hierarchy is the research's intent, even where the stack order differs from Option A's sketch:** wordmark → job banner → Pick pill → quiet quota pill → teaching line → demo card, all on one screen with no scrolling on the owner's device. Capability and action lead; the meter is a quiet pill ("● 8 of 10 free saves left · Resets 1 Nov") that keeps the reset date and drops the ledger feel without hiding the fact.
- **The demo card is the cafe pair** (owner's correction honoured), divider centred, Original/Cleaned labels, and the caption still tells the truth: "Drag divider to preview clean · Real app output".

**F2 (REQUIRED, minor) — banner sub-line wording: "Tap to return to preview".**
There is no preview to return to — the job is still running; tapping returns to the live processing view. "Preview" promises the wrong screen and will confuse exactly when the user is already waiting. Change to name the actual destination: "Tap to view progress" (or "Tap to return to your photo"). One string; do it with the F1 pass.

**Not evidenced yet (not held against these verdicts):** the with-history hero state (latest clean as hero + tray) — this install's history is empty, so Option A's second hero state has no owner evidence; the banner's **done** and **failed** states; whether a second job can queue behind the banner (if it can, the banner needs the photo's thumbnail to say *which* job — with a single active job, text-only is fine). All three join the full pass in §3. Note also that Home now diverges from S9's shared grid (hero + tray vs grid) — **owner-approved for Home only**, recorded as reconciliation D7; S9 keeps the grid, and Review 02's F6 shared-grid ruling now binds S9 and the history surfaces, not Home.

## 3. The full pass — owed when the implementation lands on main

Per the brief, when the commits arrive I will run the harness pass on this implementation: light + dark renders of both screens; 1.30 text scale on both (the status card's two-line expectation and the quota pill are the truncation risks); the with-history hero state; banner done + failed states (failed must read as a state, never as an error dead-end, and must state the no-charge fact); Processing in its *processing* stage (post-upload label + indeterminate treatment); Cancel's tap target and its no-charge confirm dialog in the new layout; the beam in dark mode. Verdicts from this screenshot pass stand unless the full pass contradicts them.

## 4. Reconciliations recorded in DESIGN_DIRECTION.md (§11)

- **D7** — Home/S9 divergence (owner-approved, Home only).
- **D8** — Processing treatment: the living-canvas design supersedes the darkroom approval of Review 04 (D2) for S3/S6; beam sanctioned as indeterminate-only.
- **D9** — Background copy rule: "You can safely leave the app" is sanctioned **only while** the banner/reattach flow exists; Review 02 F2 is closed by this implementation change.
