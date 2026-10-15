# Execution Prompt — PeopleGone Animation Pass (paste-ready for Antigravity)

Copy everything between the two `---` lines into Antigravity.

---

You are implementing an animation pass in the PeopleGone Flutter app (repo: people_gone, Flutter 3.47.7 / Dart 3.13.5). The design is fully decided by the design lead in `docs/design/ANIMATION_RESEARCH_2026.md` — read that file first; it is the spec. Implement exactly the animations listed below, nothing more, nothing "in the same spirit". If something below conflicts with the repo's `AGENTS.md`, AGENTS.md wins and you report the conflict instead of resolving it silently.

## Working rules (binding)

1. **Incremental commits with pushes.** Commit and push each small working step as it lands (per-screen or per-animation), using the repo's commit format `<phase>-<task>: <summary> (FR-xx, §n)`; use the prefix `feat-motion:` where no phase/task applies. Never hold a finished animation for a big final push.
2. **Green before you say done.** `flutter analyze` clean and the FULL `flutter test` suite passing after every step. No exceptions, no "tests to be fixed later".
3. **Evidence for the owner's eyes.** Animation cannot be judged from stills: for EACH screen you animate, produce a short screen recording (5–10 s, or a frame-strip of ≥6 frames across the motion) of the animation running on the harness/demo fixtures, saved under `test/goldens/motion/` and committed with the step. Also regenerate the existing golden stills if your change alters first frames.
4. **Motion tokens, one system.** Create/extend a single motion token set (in the existing theme/size token files per repo conventions): two durations only — fast 180 ms (feedback/toggles), standard 300 ms (screens/sheets/reveals); one easing character: springs/curves with NO visible overshoot (calm, Material "standard" character — not the bouncy "expressive" one); fades never bounce. The only longer motions are the named exceptions (demo sweep ≈1.2 s, result dissolve ≈450 ms). Animate ONLY transform and opacity properties for UI elements.
5. **Reduced motion is part of every item, not a later pass.** Read the OS setting (`MediaQuery.disableAnimations`). When on: spatial movement becomes a ≤150 ms crossfade or an instant change; all loops stop; the teaching sweep/nudge never run; the processing beam becomes a static line.
6. **Interruptibility.** No animation may block input; every animation must be cuttable by the next tap/navigation. Nothing locks the UI for longer than 350 ms.

## Do NOT touch

- **Copy and facts:** no string changes anywhere except none at all. All user-visible text stays byte-identical.
- **Processing honesty:** stage labels still derive only from real states; the upload % only ever shows the real transferred fraction (never tween it toward a value the bytes have not reached); the beam stays indeterminate and must never map to progress; no timed/scripted sequences that imply work.
- **The paywall (S8), pricing, saves logic, the API/gateway/worker**, and the Phase A–D removal features.
- **Layout/composition of every screen** — positions, sizes, colours, and content are already approved. You are adding motion to the approved screens, not redesigning them. If an animation seems to need a layout change, stop and report it instead.
- No new packages unless a listed item is impossible without one — report first.

## The animations to implement (the complete list)

**App-wide**
1. One page-transition family: fade + small slide (~300 ms, standard token), same for all routes; back navigation reverses it. Sheets/dialogs keep sliding from the bottom with the same token.
2. Press feedback on primary buttons and selectable chips: scale to 0.98 on press with a spring back (fast token, transform only).
3. Light haptic tick (`HapticFeedback.lightImpact` or the repo's existing equivalent) on exactly three events: toggling a person/distraction chip state on S4, pressing S4's confirm, and a successful photo save on S7. Nowhere else.

**Home**
4. Demo card: the FIRST time the card is visible in a session, animate its before/after handle sliding to one side and back to centre once (≈1.2 s total, ease in-out). Any touch on the card cancels it immediately; it never runs again that session and never loops. Skipped entirely under reduced motion.
5. Job banner: when the banner appears or its status changes (processing → done/failed), animate entry with a slide-down + fade (standard token). No bounce.
6. Home history section: single block fade-in when it first loads with data. NO per-item stagger anywhere on Home.

**Pick flow**
7. Shared-element (Hero) transition: the picked photo grows from the post-pick state into the Processing screen's photo frame. PERFORMANCE RULE: the flight must use a display-resolution copy of the image, swapping to the full image on landing; if smooth 60 fps flight cannot be achieved on the harness with that rule, fall back to transition #1 and report that you did.

**S4 Proposal**
8. Results reveal: when detection results arrive, canvas outlines and the chip trays fade in together in ONE beat (fast/standard token). No per-item sequencing or stagger.
9. Toggle feedback: tapping a canvas item or chip crossfades its state colours (ring, outline, state pill) and applies a subtle scale settle on the chip (fast token, no overshoot); the status sentence's text crossfades when its counts change. Must remain fully interruptible at rapid tap rates.

**Processing (S3/S6)**
10. Stage title crossfade (~200 ms) when — and only when — the real stage state changes. Entry of the photo frame + bottom tray uses transition #1's character, once. Beam behaviour unchanged (indeterminate sweep; static line under reduced motion).

**Result (S7)**
11. First-open reveal: crossfade/dissolve the original photo into the cleaned photo once (≈450 ms) when a result first displays. Use display-resolution copies for both images. Never auto-repeats or loops; afterwards hold-to-compare and the slider work exactly as now.
12. Save success: on a successful save, the Save primary morphs to a check icon + the EXISTING "Saved" state string treatment used elsewhere in the app (do not invent new copy — if no such string exists, keep the button label unchanged and show only the check icon morph), holds ≈1.2 s, then settles. No bounce, no confetti, nothing else celebrates.
13. Compare handle: the first time a result shows, the compare handle nudges ~8% of width and returns, once (≈600 ms). Touch cancels; skipped under reduced motion.

**Brush (S5)**
14. Undo: the undone stroke fades out (~150 ms). Clear: all strokes fade out together (~150 ms).
15. Reflection guide outline (Phase D entry): fades in (~250 ms) when the brush opens with a guide region; the outline is static thereafter. No marching-ants/dash animation.
16. Brush-size preview dot: its diameter animates smoothly (fast token/spring) as the slider value changes.

**History (S9 + Home tray taps into detail)**
17. Shared-element (Hero) grow from a history tile into its detail/result view, with the same display-resolution flight rule as #7 (fallback to #1 with a report if it cannot stay smooth).
18. Delete: after the existing delete confirmation, the tile fades + scales out (~250 ms) and the grid animates the gap closed (transform-only).

**Settings (S10)**
19. Theme switch: light↔dark changes crossfade the app theme (~250 ms colour transition) instead of a hard cut. All other Settings behaviour keeps standard control motion only.

## Explicitly forbidden (do not add, even optionally)

Confetti or any celebration choreography; sparkles, shine/glow sweeps; shimmer/skeleton placeholder animations; one-by-one or staggered reveals that imply the server worked sequentially; number count-up/tween animations on any real value (saves, percentages, counts); looping motion on any photo (no Ken Burns, no auto-playing before/after); bouncy/overshooting springs; parallax, tilts, 3D flips; animating layout properties (width/height/padding) of photo surfaces; a marching-ants guide outline; haptics anywhere except the three events in #3.

## Reporting

After each pushed step, leave a short note in the commit body: which numbered item(s) it implements and where its recording/frame-strip lives. At the end, post a summary: items completed, any fallback taken under #7/#17 with the reason, and the final analyze/test result.

---
