# Architecture Decision Record: Cam Mascot — Native Vector Rig

- **Document:** `docs/architecture/cam-mascot.md`
- **Status:** DECIDED — native Flutter vector rig (CustomPainter + code-driven state machine)
- **Date:** 2026-10-24
- **Decided by:** Lead agent, under the owner's standing instruction (2026-10-24) to execute the mascot build without further approvals and to take and log final decisions. Owner-commissioned feature; placements and expression set locked by the owner in `~/workspace/peoplegone/MASCOT_EXECUTION_PLAN.md`.
- **Governing Specification:** `PEOPLEGONE_REQUIREMENTS.md` §4 (S1 Home, S6 Processing, S8 Paywall) — the mascot itself is an owner addition not specified in the Requirements; per AGENTS.md, unspecified choices resolve (a) simpler, (b) cheaper, (c) more private, and are recorded here.

---

## 1. Context

The owner commissioned a living mascot ("Cam", a blue chameleon in the F3 design) for three placements only:

- **Home (S1):** circular avatar, 44dp, top-right on the wordmark row — face only, idle expressions.
- **Processing (S6):** half-peek from the right screen edge over the photo — 50% of the character's width visible, expressions while processing runs.
- **Paywall (S8):** full sitting presenter centred below the "Restore Purchases · Not now" row, ≥24dp gap.

Result screen: no mascot. Analyzing/Review: out of scope. Expression set is closed (neutral, blink, soft smile, curious glance, calm wait) — gentle, never exaggerated. Motion must obey the app's calm law (180/300ms tokens, transform+opacity, no overshoot; system reduced-motion renders a still frame). Total mascot asset weight ≤150KB. One character definition must serve all three modes (consistency by construction).

## 2. Decision

**Cam is a native Flutter vector rig:**

- The character is hand-authored once as vector geometry (named parts: body, belly, tail, crest, head, turrets, eyeballs, pupils, eyelids, muzzle, smile, paw) in a single Dart rig file, rendered by a `CustomPainter`.
- Expressions and idle behaviour are a **pure Dart state machine** (`evaluateCamFrame(elapsed, mode)`) implementing the three idle states named in the plan — `avatarIdle`, `peekIdle`, `presenterIdle` — over one shared timeline design. It is deterministic and unit-testable; the widget only supplies elapsed time.
- A hand-authored SVG master (`assets/icons/ic_cam.svg`, same geometry, named groups) ships as the artwork record and static fallback. Runtime rendering is the painter (flutter_svg cannot animate sub-parts); both forms are the same drawing, so they cannot drift in design, only in medium.
- **No new dependencies.** `rive` and `lottie` packages are NOT added.

## 3. Alternatives considered and rejected

- **Rive (.riv + `rive` package)** — the execution plan's nominal route. Rejected on evidence: a `.riv` binary cannot be authored in this environment — Rive state machines and artboards are built in the Rive Editor GUI, and no headless/CLI authoring path exists (Rive docs/community tooling are read/export only). The runtime also adds ≈935KB (GitHub API size for rive-flutter) against a 150KB total mascot budget. Choosing Rive would ship either nothing or an unverifiable binary — both fail the contract's "fully built and verified here" requirement.
- **Lottie (`lottie` package, hand-authored JSON)** — viable but inferior here: JSON supports transform animation and path morphs only with matched vertex counts; production character practice is baked segments/state swapping, and hand-authoring a multi-part character rig as raw JSON keyframes is error-prone and hard to golden-test per expression. Segment control from Dart (frame ranges) is workable, but expression correctness would rest on frame bookkeeping instead of one evaluable function.
- **Raster sprites / generated images** — rejected by the plan itself (§2): AI renders demonstrably drift between generations (the mockup rounds changed the character's face twice), and raster frames cannot hold one consistent definition across three modes and two themes.

## 4. Design decisions inside the rig

- **Sizes are fixed dp tokens, not percentages** (Conventions §6.4 forbids percentage sizing): avatar 44, peek height 110 (the plan's 96–128 clamp nominal), presenter 120 — added to `AppSizes` as mascot tokens. Position guarantees in the plan (§3/§6) then hold exactly, and measurement tests can assert them numerically.
- **Colours are palette tokens:** Cam's tones (body/shade/belly/deep/shine) join `AppPalette` in light + dark, derived from the existing blue family (primary `#2563EB` lineage). `app_colors.dart` remains the only file with colour literals.
- **Idle timing (research-informed):** blink roughly every 3.6s (industry range 3–5s), blink duration ~160ms (Duolingo-class 120–180ms), glance held ~1s with 300ms ease transitions, breathing scale amplitude ~1.2% on a ~3.6s cycle. Timing is FIXED per mode (slight phase offsets between modes) rather than randomised — determinism is what makes the rig golden-testable, and fixed gentle timing serves the calm law. Easing: `easeInOut` for blink, `easeOutCubic` returns — the app's `AppMotion` curves; no overshoot anywhere.
- **Reduced motion:** with `MediaQuery.disableAnimations` set, the widget never starts its ticker and renders the neutral still frame.
- **No rock prop** (present in the F3 art and v2 mockup): set dressing, not character; the sitting pose reads without it.
- **Decorative semantics:** the mascot carries no information and no action in v1 → wrapped in `ExcludeSemantics`; no strings are added (`app_strings` untouched), no analytics, no data behaviour change (`docs/compliance/store-forms.md` therefore unchanged).

## 5. Evidence addendum (post-decision research, same day)

Two corrections/completions to the research record, neither of which changes the decision:

- Duolingo's stack is mixed: lesson-character animation is Lottie-based, while the Lily video-call character is a Rive state machine ("modular actor", per Rive's case study). What this project borrows is the *pattern* — one rig, layered expression states, calm idle variation — not either tool.
- A Rive CLI exists in technical preview that can build a `.riv` headlessly from a text scene format. It does not rescue the Rive option here: a clean file requires `--publish` signing bound to a Rive account on a paid plan (unsigned output may carry a watermark), the character would have to be hand-written in that text format with no visual feedback loop, and the current Flutter runtime is ~2.4MB (Rive's published runtime sizes) against a 150KB mascot budget. The rejection stands, strengthened.

## 6. Verification commitments (plan §6)

- `flutter analyze` clean; `flutter test` green (any pre-existing cross-machine golden pixel failures identified as such, with evidence).
- New goldens for Home / Processing / Paywall with Cam, plus numeric measurement tests: avatar centre vs wordmark centre within ±2dp; peek visible fraction 50% ±3%; presenter gap ≥24dp; zero overlap with interactive elements.
- Consistency: a single rig definition renders all three modes in code (same painter + same frame evaluator) — stated in the change and covered by widget tests pumping all three modes.
- Asset weight: the SVG master is the only shipped mascot asset; its byte size is measured and reported (runtime adds no asset bytes).

## 7. Sheet-art supersession (owner, 2026-10-24)

The vector rig (§2) and the F3-artwork rig that followed it are both
superseded. The owner replaced the character with a teal chameleon
and then directed that the shipped art be the owner's approved
4-panel sheet drawings themselves — never a redrawn twin.

- Assets (`assets/icons/`): `ic_cam_avatar.webp` (sheet 01, baked
  peach ring painted out), `ic_cam_results.webp` (sheet 04, baked
  green ring painted out), `ic_cam_analyzing.webp` and
  `ic_cam_processing.webp` (full panels, only the outer white made
  transparent — nothing cropped). Total ~123KB. The vector painter
  (`cam_painter.dart`) and SVG master (`ic_cam.svg`) are deleted;
  they have no remaining references.
- The circle is drawn in code, never baked into the artwork:
  `CamMascotArt` draws a `BoxDecoration` circle border (peach
  `mascotRing` for Home, green `mascotRingReady` for Results Ready,
  both palette tokens) around a `ClipOval` image.
- Modes (`CamMode`): `avatar` (Home top-right, 44dp),
  `avatarSmall` (Brush / History headers, 32dp),
  `analyzing` (centred whole magnifier, 200dp wide),
  `processing` (centred whole at-computer, 240dp wide),
  `resultsReady` (Result top-right circle, 44dp). Analyzing and
  Processing render whole with `BoxFit.contain`, no clip, no card,
  on the clean screen background; nothing is cut out or cropped.
  Paywall has no mascot. Result's photo stays clean: the avatar
  sits in a header row above the photo, never over it.
- Motion is calm breathing only (±1.2%, 4s cycle) from
  `evaluateCamFrame`; each sheet drawing already carries its own
  face, so there is no blink / glance / tilt rig any more.
  Reduced motion and the test environment still render the
  neutral still frame.
- Verification (Flutter 3.47.7, 2026-10-24): `flutter analyze`
  clean; mascot unit + capture measurement tests pass (17/17);
  new goldens in `test/goldens/mascot/`. Full suite 225 pass /
  16 fail, all 16 pre-existing in the working tree (stale
  copy/motion/save-flow tests, unrelated to the mascot).
