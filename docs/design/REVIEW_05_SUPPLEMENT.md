# Review 05 — Supplement: The Design Lead's Audit

**Date:** 2026-10-14
**Author:** UI/UX design lead, acting under DESIGN_DIRECTION §10 at the owner's explicit instruction (2026-10-14): judge these screens with my own professional judgement — my criteria, my structure, my call. This supplement supersedes the lens-structured version issued earlier the same day. Where my rulings converge with it, that is because I stand by them; where this audit goes further (a system ruling on card language, D12), the new ruling governs.
**Material:** The owner's two screenshots of the new build (Processing mid-job; Home with a background job running, light theme). **Design review, not launch approval.**

## My criteria

I judge these screens against the direction this project already runs on, in this order:

1. **The north star** — intuitive, easy to understand, modern minimal.
2. **The photo is the app** — photographic surfaces carry the design; chrome exists to serve the photo and the job, and must justify itself.
3. **A screen is a finished arrangement** — balance, rhythm, and a resting point for the eye. A screen that stops mid-air is not minimal; it is incomplete. Minimal is *nothing unnecessary*, not *as little as possible*.
4. **Nothing imitates information** — the worst offence in UI is a shape that mimics a signal it doesn't carry: a fake status, a fake progress, a fake selection. Absence is honest; imitation is not.
5. **Calm is a visual property, not just a copy property** — a screen that meters, pulses and stacks at the user is not calm, whatever its words say.
6. **One language per screen** — one alignment story, one corner story, one border story. Variety inside a single screen is noise; variety between screens is fine.

---

## What is GOOD — and worth protecting

Credit first, because these are the decisions the fixes must not break.

- **Killing the darkroom was the redesign's best decision.** The framed photo at natural brightness on the theme canvas treats the user's photograph with respect — the previous screen treated it as wallpaper behind a terminal. This is "the photo is the app" finally honoured on the waiting screen.
- **The background job banner is a genuinely good invention.** A job that follows the user home, states itself plainly, and opens back up on tap. It converts the product's worst fact (a two-minute wait) into evidence of competence. Protect it.
- **The demo card remains the best teaching device in the app.** A real before/after pair with a draggable divider teaches the entire product in one gesture, with no tutorial, no onboarding, no hype. Its caption tells the truth about what it is.
- **The beam, as an idea, is right.** A two-minute static screen is a dead screen; a slow indeterminate sweep is a pulse, and a pulse is what a waiting screen needs. It does not pretend to measure anything. (Its *weight* is another matter — see below.)
- **Discipline held everywhere else:** the wordmark appears once; no sparkles, gradients or hype words anywhere; the quota states its fact including the reset date without a meter shouting about limits; Cancel is an honest word, not a red button inventing danger. The calm, factual voice survived the redesign intact.

## What is WRONG

Ordered by how much damage each does.

**W1 — Both screens are unfinished arrangements.** On Processing, everything ends at Cancel, ~70% down, and the remaining quarter-plus is unstructured porcelain. On Home, the content ends at the demo card, ~55% down, and the bottom ~45% is bare. This fails criterion 3 outright: the eye is given a path and then dropped. It is also, not coincidentally, the failure this project keeps re-committing — the first-run void, the with-history void, the darkroom's dead surround were all this same mistake in different clothes, and it is now a standing rule (D10) rather than a per-screen observation: **a primary screen that ends in unstructured empty space is not composed, and I will reject it on that ground alone.**

**W2 — Home's emphasis is inverted.** The largest text after the wordmark is a prose paragraph; the hero it introduces carries the smallest text on the screen. The demo *is* the persuasion — the paragraph is its caption. As built, the caption outranks the picture, and the picture is also physically too small: the adopted design specified a ~60%-height hero and the build delivers ~30%, parked last in the stack. A screen whose strongest asset is its smallest element has its hierarchy backwards.

**W3 — Three shapes imitate information they don't carry.** (a) The quota pill's blue dot performs "status" — live, unread, active — and there is no status; it is a decoration wearing a signal's clothes. (b) The empty progress track in the status card performs "progress" at 0% and reads as a stray divider; a track that is not filling or pulsing is a lie of form. (c) The banner's blue border performs "selected/focused" — the language of input fields — on a notice. Each is small; together they are the difference between a designed screen and an assembled one, because a user reads shapes before words. Criterion 4 is mine and I am applying it strictly: **all three go.**

**W4 — Processing's junction is over-layered.** The status card overlaps the photo; the action pill also overlaps the photo; the photo's bottom corners peek out beside the pill. Two overlaps is a pile-up, and the peeking corners make it look like a rendering error. One overlap per junction is a device; two is an accident.

**W5 — The stopwatch contradicts the screen's own voice.** The card's words say "calm, ~2 minutes, leave if you like"; its elapsed timer says "0:24 and counting". A ticking meter is the visual opposite of the reassurance printed beside it. The duration line already carries the time information. The timer goes — not because it is untrue (it is the most measured thing on the screen) but because truth is a threshold, not a justification: everything shown must also *earn* its place.

**W6 — The primary action on Processing is its faintest element.** A white pill on a near-white canvas, defined only by shadow — while the screen's most saturated object is a decorative beam carrying no information. Accent and solidity are spent in exactly the wrong places: loud where nothing is meant, faint where the user's one action sits.

## What could be IMPROVED — my rulings

These carry my authority as design lead (§10). Factual/copy items F1 (stage label) and F2 (banner wording) from Review 05 stand unchanged and are not repeated here.

- **R1 — Anchor Processing's status cluster to the bottom.** Status card, background action and Cancel become a bottom-anchored group (the tray the adopted option specified); the photo takes the space above; spare room falls between them as gallery air. Fixes W1 and W4's reading of Cancel as an afterthought.
- **R2 — One overlap only.** The photo card ends where the status cluster begins; nothing peeks. Fixes W4.
- **R3 — Restore the hero's scale on Home.** The demo (or, with history, the latest clean) is the screen's dominant mass — toward the adopted ~60%, never a ~30% card trailing a queue of containers. Fixes W1 and W2 together.
- **R4 — Demote the teaching line to body size.** It introduces the hero; it does not headline the screen. Fixes W2.
- **R5 — Strip the imitation shapes.** No status dot on the quota (and the quota itself becomes a plain text line in the column — its pill container borrows emphasis the fact hasn't earned); no progress track unless it is filling or pulsing; the banner takes the same neutral border as every other card — its spinner and words already say "active". Fixes W3 and W6's accent misallocation in part.
- **R6 — Give "Work in background" a defined treatment.** A border or a fill — the action must be the most solid thing in its zone. Fixes W6.
- **R7 — Split the status card's text by owner.** Duration stays with the stage line. "You can safely leave the app." leaves the card and captions the button it justifies. The card then reads: one stage, one expectation — nothing else.
- **R8 — Reduce the beam's weight.** Thinner or softer; it is a pulse, not a headline. Its sanction remains indeterminate-only.
- **R9 — Cut the caption to provenance.** "Real app output." The divider's handle already teaches the drag, and the blue hand icon is the only clip-art in either screenshot. Instruction that never leaves becomes noise; provenance never stops earning its place.
- **R10 — Shorten the banner subtitle to the destination.** The duration half duplicates the screen the user just left and isn't a remaining-time figure in any case.

## One system ruling beyond these two screens

**D12 — One card language, app-wide.** A single card radius and a single border treatment (neutral hairline) for every card surface in the app; colour is spent on the photo, the primary action, and genuine state — never on container outlines. Home currently shows four border treatments in its top half; that is how template apps look, and it ends here.

## Unjudged, honestly

Motion (the beam's speed and easing, banner transitions) cannot be judged from stills, and neither can these builds in dark mode or at 1.30 text scale. Those join the full harness pass already owed when the implementation lands on main, alongside the with-history hero and the banner's done/failed states. My composition verdicts above do not wait for that pass: **as composed in the owner's screenshots, both screens are rejected — concepts approved, elements largely approved, arrangements not finished.** R1–R10 are the finish.

---

## Research grounding (added 2026-10-14, at the owner's instruction)

My verdict above was reached from the screenshots. Before it stands as final, the owner asked that it be checked against the field: the current versions of the direct competitors and top photo tools, and the gallery/trend sources. Method note: I cannot install these apps in this environment, so competitor evidence is vendor documentation, vendor blogs, and hands-on walkthroughs — paraphrased, with sources named; gallery evidence is Mobbin's published glossary and a Mobbin-derived pattern synthesis. Where a ruling still rests on my judgement rather than an observed pattern, it is labelled **(inference — mine)**. One ruling is *qualified* by the evidence (D12, below). None was overturned.

### What the field actually does

**1. Processing happens in place, on the photo — nobody builds a waiting room, and nobody shows a clock.**
Apple Clean Up works inside the photo editor: objects are outlined in colour on the photo itself, removed in place; even the server-based High Quality mode in current iOS — which a hands-on account notes can take a minute or two — stays in the editor behind a single action button. Lightroom's Generative Remove is likewise one click inside the editor, non-destructive, with no separate waiting surface in any coverage. SnapEdit's removal finishes "in a few seconds" in-editor (vendor guide), and TouchRetouch processes on tap of its Go button in the editor. In **none** of the seven tools' documentation or walkthroughs does an elapsed timer, a stopwatch, or a percentage-of-wait appear. PeopleGone's two-minute server wait is a genuinely different problem — a waiting surface is justified here in a way it isn't for them — but the field's vocabulary for waiting is *stage + expectation*, never clocks. **Grounds: W5 and the elapsed removal (R-adjacent, D11a).** Sources: Apple Clean Up walkthroughs (Digital Trends; MacObserver; Trusted Reviews on the current iOS tools); Adobe's Generative Remove coverage (ZDNet; DIY Photography); SnapEdit's vendor how-to (snapedit.app).

**2. Actions live at the bottom.**
TouchRetouch's main tools and its Go button sit in the bottom toolbar (multiple walkthroughs: gHacks; Mobiography; iPhone Photography School). Google Photos' Magic Editor puts its controls in the bottom corners, with the proceed action at bottom-right (Popular Science walkthrough). Photoroom's primary "Start from Photo" button sits at the bottom of its Create/Home screen (Photoroom's own blog). A Mobbin-derived synthesis of current iOS patterns likewise describes anchored bottom docks set just above the safe area as the prevailing pattern. **Grounds: R1 (bottom-anchored status/action cluster)** — with this honesty note: the bottom-action norm is observed for *editor actions and primary CTAs*; no competitor has a minutes-long waiting screen to copy, so the tray *form* for a waiting surface remains **(inference — mine)**, built from that norm.

**3. Decorative motion on photos is a liability with a paper trail.**
Google Photos added an animated shimmer over photos this year; coverage in Android Police and Android Authority documents sustained user backlash — distraction, even motion sickness — ending with Google shipping an off switch. **Grounds: R8 (reduce the beam's weight)** and the beam's indeterminate-only sanction. It also sharpens the beam's evidence position: a seconds-long analysis sweep has precedent (SnapEdit's detection scan, per the project's teardown), and in-place shimmer has precedent (Google), but a minutes-long sweep over a photo has **no field precedent** — the beam remains the least-evidenced element on either screen, sanctioned as **(inference — mine)**, dosed per R8, and first in line for removal if owner testing finds it irritating.

**4. A glanceable ongoing-task surface carries ONE essential fact.**
Apple's Human Interface Guidelines for Live Activities — the platform's pattern for tracking an ongoing task at a glance — direct designers to show only the single most essential, glanceable fact, with detail behind the tap into the app. PeopleGone's job banner is that pattern inside the app. **Grounds: R10 (banner subtitle cut to one fact — the destination)** and the banner's basic design, which I rated "good" above and now rate *grounded*, not just liked. Source: Apple HIG, Live Activities.

**5. Homes in this category are either a photo surface or a start surface — never an admin column.**
Photoroom's Create/Home leads with starting a design from a photo (vendor help centre). Google Photos and VSCO open into the photo library itself (VSCO per the project's teardown in HOME_AND_LOADING_RESEARCH.md; not independently re-verified in this pass). SnapEdit's home is a tool menu — the exception, and it is a multi-tool editor, not a single-job app; PeopleGone's single-job peers put the photo or the start action first and largest. **Grounds: R3 (hero scale) and W2 (inverted emphasis)** — a ~30% hero trailing a queue of containers matches no observed pattern in the category.

**6. Card systems: one radius scale — but the platform trend on colour dents D12, and I am recording it.**
The Mobbin-derived synthesis describes a consistent corner scale across current iOS apps (cards/sheets ~20–28dp, buttons to full pill) — that grounds D12's single radius and single border treatment. However, Android's current Material 3 Expressive direction — visible across Google's own apps, e.g. Photos' redesigned settings — deliberately uses *softer, more colourful, varied* containers. So "one neutral card language" is **not** the platform's only current dialect, and I won't pretend otherwise. D12 stands for this app on my criteria — calm, photo-first, single-job; container colour variety in a two-screen utility would spend attention the photo should get — but it is hereby labelled **(inference — mine)**, taken against a real counter-trend that suits content-rich apps better than this one. Sources: Mobbin-derived iOS pattern synthesis (GitHub, eldor-firdavsov/template); Android Headlines on Google Photos 7.85's M3 Expressive containers.

### Net effect on the audit

Verdict unchanged: both screens rejected on composition; concepts approved. R1, R3, R8, R10 and the elapsed removal are now grounded in observed patterns (sources above). R2, R4, R5, R6, R7, R9 rest on my criteria (one language per screen; nothing imitates information; text grouped by what it justifies) applied to the screenshots — they were always judgement calls and are labelled as such here rather than dressed as findings. The beam's existence (not its restraint) is the audit's one true leap: no precedent, my sanction, first to be cut if it irritates in real use.
