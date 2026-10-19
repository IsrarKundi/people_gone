# First-Run Choreography — Design Brief (build specification)

**Date:** 2026-10-19 · **Author:** UI/UX design lead (§10 authority) · **Builder:** Antigravity (audit handoff, Task 4) · **Verifier:** Muse
**Governing documents:** ANTIGRAVITY-HANDOFF.md Task 4 (constraints quoted in §1), the animation house rules in `docs/design/ANIMATION_RESEARCH_2026.md` and the motion tokens in `lib/core/constants/app_motion.dart` (fast 180 ms · standard 300 ms · `springCalm` · `springSettle` · `splashHold` 1200 ms). This brief invents no screens, no states, and **no copy** — there is no new user-visible text in this task; do not add any.

---

## 1. The decision (read this first)

**The intro is not a set of screens. It is a choreographed pass over the real first-run path** — splash → Home → pick → consent → analyse → Proposal → Processing → Result — with first-launch-only timing, one persisted flag, and no gates.

Why: this app has one job, and its Home already contains its teacher — the demo card, which shows the real before/after and whose handle teaches the compare by touch. A carousel or intro pages in front of that would (a) delay the job, (b) duplicate the demo's teaching in weaker form, and (c) risk exactly what the handoff forbids — invented states between the user and their photo. An intro built entirely from the app's real screens and real states **cannot fake progress**, because there is nothing in it that is not the app. The handoff's shape is preserved: *the demo card teaches; the first real clean is the climax* — the climax is the Result dissolve that already exists, reached through the user's own photo, not a stage set built for the occasion.

## 2. The beats (the complete choreography)

- **Beat 0 — Splash (unchanged, every launch).** As shipped: wordmark entrance (fade + scale — confirm it runs on motion tokens), `POWERED BY ARTIVO` footer, hold = `AppMotion.splashHold` (1200 ms), tap anywhere proceeds immediately (already implemented in `SplashController.complete()`). Exit to Home uses the standard app transition (crossfade family, standard token). No first-launch variant of the splash itself; nothing is added to it — no tagline, no "preparing" line, no progress indicator of any kind (app load time is not a state the user needs narrated).
- **Beat 1 — Home arrival (first launch only).** Home arrives **settled**: wordmark row, saves line, Pick button, teaching line all present at rest. There is NO staggered or sequenced entrance of Home's elements (per-item choreography was rejected in the animation plan — it is the template look this app refuses). The single moving element: **the demo card's teaching sweep** (already built in Task 3 on `springCalm`), which on first launch is guaranteed to run once, starting ≈400 ms after Home has landed — long enough for the eye to find the card first. This consumes that session's sweep under the animation plan's per-session rule; the two rules must not double-fire.
- **Beat 2 — First pick → consent.** Tapping Pick (available at every moment — see §3) runs the existing flow: the S2 consent sheet rises with the standard sheet motion, before the analysing screen, exactly as built. The consent sheet is the intro's trust beat and it is already in the right place; its content, order, and behaviour do not change. On every later pick the stored consent makes this beat vanish, as it does today.
- **Beat 3 — The working loop (no choreography).** Analyse → Proposal → Processing run under the animation plan's existing items (one-beat results reveal, toggle crossfades, real-stage crossfades, beam). **Nothing is added here**: no coach marks, no tooltips, no floating hints, no annotations on working screens. The intro does not narrate the app while the app is working.
- **Beat 4 — The climax: the first Result.** The cleaned photo's arrival uses the existing `springSettle` dissolve (original → cleaned) — the same reveal every Result gets. It must not be enhanced, extended, or badged for first-timers: no celebration (owner-settled, §9 Q6), no "your first clean" marker, no special copy. The intro's closing beat comes after: **when the user saves and returns Home, their own photo is in the History section for the first time** (the section's standard first-load block fade, animation plan item 6). The story the choreography tells, end to end, is factual: the demo showed the trick, the user's photo did it, Home now holds their photo next to the demo. Nothing else is needed, and nothing else is permitted.

## 3. Skippable — at every point, by construction

1. Splash: tap to proceed (exists).
2. The sweep: any touch on the card cancels it (built in Task 3); it never restarts.
3. **The real skip is the app itself:** Pick is live from the first frame of Beat 1. A user who ignores the intro entirely and taps Pick has skipped it — there is no moment at which the choreography holds input hostage, no "Get started" gate, no required viewing. Total forced exposure on first launch = the splash hold only (≤1200 ms, tappable).
4. Android back from Home behaves as it does on any launch. Nothing traps the user in a beat.

## 4. The flag — never shown twice, even interrupted

- ONE new persisted key in the existing local store, versioned: **`intro_seen_v1`** (boolean).
- It is written **before** Beat 1 plays (write-then-play): the moment the first-launch Home choreography is armed, the flag is set. If the app is killed mid-sweep, mid-consent, or mid-first-clean, the next launch is a normal launch — the intro never replays, in whole or in part. A partial viewing counts as the viewing.
- Later launches: splash → Home, standard behaviour; the demo sweep remains governed by the animation plan's per-session rule as built in Task 3 (the intro flag does not disable the sweep on later sessions; it only retires Beats 1–2's first-launch sequencing — Beat 2's consent is governed by the consent store, as today).
- A reinstall is a first launch again (correct). No "replay intro" setting or menu entry is to be added — do not build one.
- The flag is independent of consent state and of history contents: if a device somehow has history on its "first" launch (restored data), Beats 0–2 still apply harmlessly and Beat 4's closing beat simply already exists.

## 5. Reduced motion — the choreography collapses to static steps

With the OS reduced-motion setting on (`MediaQuery.disableAnimations`):

- Splash exits by a short crossfade or instant cut at hold end (tap still skips).
- **The sweep never runs.** The demo card is static; it still teaches — the Before/Cleaned labels and the caption are on the card, and the handle still drags. No information in this choreography is carried by motion alone.
- Consent sheet and all transitions use the standing ≤150 ms crossfade substitution.
- The Result dissolve becomes a short crossfade instead of the `springSettle` flight (the animation plan's global substitution applies — this brief does not create a second rule for it).
- The sequence of screens and states is IDENTICAL. Reduced motion changes how steps look, never which steps exist.

## 6. Do not build (guard list)

No onboarding carousel or intro pages · no "Get started" / "Skip intro" buttons (skipping is structural, §3 — a Skip button would admit there is something to escape) · no step indicators, progress dots, or "1 of 3" framing · no coach marks, tooltips, or spotlight cut-outs on any working screen · no new copy anywhere (no splash tagline, no first-result message, no Home annotation) · no sound · no first-clean celebration, badge, or animation beyond Beat 4 · no permission request beyond the existing consent sheet · no delay of the Pick button behind any animation · no replay entry point.

## 7. Evidence required with the build

1. A screen recording of the FULL first run from a fresh-install state: splash → Home + sweep → pick → consent → (fixture) analyse/proposal/processing → first Result dissolve → save → Home showing the first history item.
2. A second-launch recording: splash → Home directly, no intro beats.
3. Interruption recordings: (a) tap-skip on splash; (b) Pick tapped during the sweep; (c) app killed during Beat 1, relaunched — no replay.
4. The reduced-motion pass recorded with the OS setting on: static steps, no sweep, sequence unchanged.
5. Timings spot-checked against the tokens (splash hold, sweep start offset ≈400 ms, transition durations) — report the measured values, not just "matches".

**Acceptance, in one line:** a first-time user reaches their own cleaned photo through the app's real screens with exactly one taught gesture (the demo handle), zero gates, zero invented states — and a returning user never sees the choreography again.
