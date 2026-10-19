# ANTIGRAVITY HANDOFF — Framora audit follow-up (2026-10-19)

Context: the design & UX audit (`~/workspace/peoplegone/audit-2026-10-19/AUDIT-REPORT.md`,
work split in `WORK-SPLIT.md` in the same folder) divided the fixes between Muse and
Antigravity. **Muse's half is DONE and pushed** (commits `7451260`, `8397f3b`, `acaba00`,
`28c287c`, `fe52459`, `8034092`, `37b3240`, `da82ccd`, `c99204e`, `f6cd75a`, `b1016c4`):
Proposal palette wiring, the Phosphor system foundation, semantic haptics, Poppins display
role, splash de-doubling, strings sweep, micro-type + a11y, springs, photo-frame system,
golden tolerance. What follows is YOUR half. Read the repo `AGENTS.md` first — its rules
bind all of this (tokens only, strings only via `app_strings`, no hardcoded prices, analyze
clean + tests passing before anything is called done, commit format `<phase>-<task>:
<summary> (FR-xx, §n)`).

## ⛔ DO NOT CHANGE — read first

1. **Never restore commented-out code or UI.** Anything commented out was commented out
   INTENTIONALLY by the owner (ruling 2026-10-19). This explicitly includes:
   - the `FeaturedCleanCard` block in `lib/features/home/view/home_view.dart`, and
   - the Settings app-bar entry in the same file (Settings stays unreachable BY DECISION —
     do not "fix" it, do not clean its screen).
   The failing-test side was already reconciled: `home_flow_test` now asserts the card's
   ABSENCE. Do not re-add the card to make any old expectation pass.
2. **Do not loosen the golden tolerance** in `test/flutter_test_config.dart` (per-channel
   24/255, 2% area). If a golden still fails after re-recording on your machine, report it
   — do not widen the numbers.
3. **Do not change copy wording.** Existing string VALUES in `app_strings.dart` are
   design-lead-approved. New copy (paywall) must be proposed as keys and approved by the
   design lead before merge.
4. **Never hardcode prices.** Prices come from `PurchaseService` only. If the service
   returns nothing, the layout renders its price slot empty — never a typed `$19.99`.
5. **Do not change** palette values (`app_colors.dart`), `AppIcons` glyph choices, the
   `AppHaptics` patterns, `AppMotion` spring parameters or splash timings, or the app
   architecture. No new permissions. "Magic Eraser"/"Magic Editor" stay banned everywhere.

## Task 1 — Phosphor migration, feature screens (P1)

The system is built: `lib/core/constants/app_icons.dart` is the ONLY icon source
(Phosphor, `phosphoricons_flutter`). Core widgets are migrated. ~37 `Icons.*` call sites
remain in `lib/features/**`. Migrate every one through `AppIcons`:

- Add the entries you need to `app_icons.dart` (semantic names, Regular default,
  `…Fill` suffix for the Fill weight — Fill is for SELECTED/ACTIVE states only,
  Duotone only where a screen already has a premium accent spot; when in doubt, Regular).
- Agreed concept mapping (from the icon research — do not substitute other glyphs):
  person-remove → `userMinus` · person → `user` · keep/check → `check` · close/remove →
  `x` · brush → `paintBrush` · fix/wand → `magicWand` · eraser → `eraser` · history →
  `clockCounterClockwise` · layers → `stack` · compare → `arrowsLeftRight` (ONE glyph
  everywhere — today compare uses three different Material glyphs; unify on this) ·
  share → `shareNetwork` · undo → `arrowCounterClockwise` · camera/pick → `camera` ·
  info → `info` · settings gear → `gear` · chevron/back/forward → `caretLeft`/`caretRight`.
- Files (from the audit inventory): home (job banner, tray, demo card), proposal
  (view + cards), processing, result (view, compare slider, keeper sheet), brush
  (view, dock, stroke bar), history (grid, detail), settings.
- Acceptance: `grep -rn "Icons\." lib/features` returns nothing; `flutter analyze` clean;
  full test suite no worse than the baseline you started from; before/after screenshots
  of every touched screen in light AND dark for the verification pass.

## Task 2 — Build the S8 paywall screen (P0-size build)

Today the route and an empty binding exist (`lib/features/paywall/`); there is no page,
and a credit-blocked save dead-ends in an info dialog. Build the screen:

- **Design first:** get the design lead's brief before building (governance). Direction
  from the feel research: photo-first — when the user arrives from a cleaned photo, the
  hero is THEIR OWN before/after (original vs cleaned), headline in
  `AppTextStyles.displayBrand` (Poppins role, already in `app_text.dart`), outcome
  wording, Annual as the visual anchor, Monthly and Lifetime as quiet secondary rows,
  ONE focal CTA, calm factual voice, no countdowns, no fake discounts, no confetti.
- **Wiring:** plans and prices ONLY via `PurchaseService` (stub-safe: render price slots
  from the service; empty when it returns null). RevenueCat purchase calls are OUT of
  scope — no store accounts exist yet. The CTA may be presentational/disabled-with-note
  until RevenueCat lands; do not fake a purchase flow.
- **Entry points:** (a) Home saves line tap when saves = 0 (decided behaviour, §9 Q2);
  (b) the credit-blocked save path — replace the info-dialog dead end with navigation to
  the paywall, keeping the dialog's factual wording as the paywall's arrival context.
- **Constraints:** strings via new `app_strings` keys (copy approved per ⛔3), tokens
  only, ≤400 lines per file, feature structure per conventions (binding/controller/view).
- Acceptance: route renders in all states (with/without a hero photo, prices present/
  absent); analyze clean; widget tests for the two entry points; screenshots for the
  design-lead review.

## Task 3 — Demo-handle spring (P2, small)

`InteractiveDemoCard`'s teaching sweep still runs on a fixed `TweenSequence`. Convert it
to `AppMotion.springCalm` exactly the way the compare slider was done in commit
`c99204e` (`compare_slider.dart`: unbounded controller + `animateWith(SpringSimulation)`,
user input cancels the run). Do not invent different parameters.

## Task 4 — First-run choreography (P2)

After a design-lead brief: first launch only — splash → a short intro that ENDS in the
user's own first cleaned photo (the demo card teaches; the first real clean is the
climax). Hard constraints: no fake progress or invented states anywhere in the flow;
reduced-motion collapses it to static steps; it must be skippable and never shown twice.
Follow the animation house rules (`docs/design/ANIMATION_RESEARCH_2026.md`): two durations
(fast 180 / standard 300) + the named exceptions only.

## Task 5 — Re-record the 6 stale goldens (after Task 1)

On THIS machine `flutter test test/goldens/` is 56 pass / 6 fail under the new tolerance.
The 6 are stale against APPROVED changes, not regressions: `home_horizontal` ×3 (tray
badge size + photo radius changed), `result_motion` item 11 (dissolve is now a spring,
by design) and item 12 (Result outcome line is now Poppins), `proposal_motion` toggle
crossfade (cross-machine animation-phase frame). After your icon swap lands, re-record
once on your machine: `flutter test --update-goldens test/goldens/`, commit the images
with a message naming the approved changes they reflect, and report the new totals.

## Verification

Every batch gets Muse's verification pass (analyze, full tests, greps, live checks)
before it is called done — the standing pattern. Report results from THIS machine as
yours and expect them to be re-run elsewhere; a claim that only holds on your machine
will be reported as such.
