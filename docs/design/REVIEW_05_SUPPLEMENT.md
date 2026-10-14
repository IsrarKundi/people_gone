# Review 05 — Supplement: The Owner's Three Lenses

**Date:** 2026-10-14
**Reviewer:** UI/UX design lead
**Material:** The same two owner screenshots as Review 05 (new Processing mid-job; new Home with a background job running, light theme, owner's device). Judged from those two stills only.
**Brief (owner's, verbatim in intent):** do not judge functionality. Judge (1) whether the screens actually *look* good — bluntly, specifically; (2) emptiness — the owner named this himself: *"not enough things on the screen"*; (3) necessity — *"unnecessary things being shown"*: every visible element on trial, none pre-approved.
**Relation to Review 05:** this supplement is the owner's clarified brief answered in the form he asked for. Its verdicts are consistent with Review 05 as reframed (commit `05c4d0a`): **both screens rejected on composition**. Review 05's factual findings (stage label, banner wording) stand and are not repeated here.

---

## Lens 1 — Looks audit: does it look professionally designed?

### Processing

**Typography.** The stage title is the one well-judged text on the screen: title-size, semibold, quiet. Everything under it collapses: three facts (elapsed, duration, leave-the-app) are set as a single two-line grey paragraph, so the card's text hierarchy is *one bold line, then mush*. Grey text at body size carrying three unrelated facts is how utility apps write status; designed apps give each fact one place and one weight.

**Spacing rhythm.** There isn't one. Photo → status card is an *overlap* (negative gap), card → pill is a small gap, pill → Cancel a medium gap, Cancel → screen bottom is an infinite gap. Four different spacing ideas in one column, and the rhythm dies completely at Cancel.

**Alignment.** The one thing that holds: a single centre axis for actions, left-aligned text inside the card. Nothing to fix here — which is why the failures stand out: they are proportion and treatment failures, not alignment failures.

**Card treatment.** Three corner languages in one junction (photo card ≈24dp radius, status card ≈20dp, pill fully round), and the status card and the pill *both* overlap the photo card, whose bottom corners peek out as photo slivers beside the pill. Stacked overlaps with a third element peeking through is the screen's most amateur moment — it reads as a rendering accident, not a device.

**Colour balance.** The screen is two screens stitched at the status card: the top ~60% is a rich, dark, warm night photograph; the bottom ~40% is cool porcelain with almost no accent colour in it at all. The only cobalt below the photo is *none* — the beam is inside the photo, Cancel is grey, the action pill is white. A designed screen distributes its accent; this one spends it all at the top.

**Verdict (looks):** handsome photograph, unfinished screen. The photo card alone would pass anywhere; everything below it is where the amateur tells concentrate (white pill on near-white, peeking slivers, stopwatch, empty hairline — detailed in Lens 3).

### Home

**Typography.** The hierarchy is inverted. Ranked by size: wordmark, then the *teaching paragraph* (~20sp, two lines, near-black), then the banner title — and the smallest text on the screen belongs to the hero: the demo card's labels and caption. The screen's biggest words describe the product; its actual content (your photo, cleaned) whispers. A designed first screen lets the hero carry the emphasis and keeps prose at body size.

**Spacing rhythm.** A compressed top cluster — banner, pill, pill, paragraph, card, five containers with near-uniform small gaps — followed by a hard stop and ~45% of nothing. No graduated rhythm leads the eye down; it is marched through a queue of boxes and then dropped.

**Alignment.** Two stories: a left/full-width column (wordmark, banner, Pick, teaching line, demo) and one small pill centred in the middle of it (the quota) that belongs to neither. A single centred element among left-aligned siblings always reads as a stray — here it reads as a toast notification that never left.

**Card treatment.** Four containers, four treatments, in the top half alone: banner with a *blue* border (reads as a focus ring on an input — the only coloured border on the screen), a solid-filled pill button, an outlined pill, a hairline-bordered photo card. Container soup. Individually defensible; together they are the visual noise the owner is reacting to.

**Colour balance.** Better than Processing: cobalt is distributed (button, banner spinner/border, caption icon) and the demo photo's warmth balances the middle. The failure is not colour but mass — all of it is in the top half.

**Verdict (looks):** coherent palette, wrong proportions. Nothing on this screen is ugly; it is *underweight* — a header cluster and one mid-sized card where the adopted design called for a hero.

---

## Lens 2 — Emptiness: composed, or unfinished?

**Processing — UNFINISHED.** The bottom ~25–30% below Cancel is unstructured porcelain. The eye's path is photo → card → pill → Cancel → *nothing*, and the nothing is the largest single region of the lower screen. **What rebalances it (within honesty + no-clutter): nothing new.** (a) Anchor the status card + actions to the bottom as the tray the adopted Option 1 actually specified — the same elements, bottom-anchored, with spare space falling *between* photo and tray where it reads as gallery air. (b) Let the photo card flex into the height that frees up — a portrait photo like this mosque shot can legitimately be larger. Explicitly rejected as fillers: tips, feature hints, upsell, decorative branding — emptiness is fixed by anchoring and scale, never by adding content.

**Home — UNFINISHED in this state.** The bottom ~45% below the demo card is bare. The adopted Option A specified a hero canvas at ~60% of screen height; the built demo card is ~30% and sits *last* in the stack. The research doc's own complaint about the previous Home was a "70% white void" — the redesign shrank the void; it did not compose the screen. **What rebalances it (within the rules):** (a) restore the hero toward its adopted scale — the demo card is the screen's anchor and should carry the mass; (b) the space that creates lets the top cluster loosen instead of queueing; (c) in the with-history state the hero becomes the user's latest clean (already specced) — the same rebalance, with the user's own photo as the mass. Again: no filler elements are needed or permitted.

**Standing rule recorded (D10):** a primary screen whose content ends in unstructured empty space in its bottom quarter is a composition reject, whatever its elements' individual quality.

---

## Lens 3 — Necessity audit: every element on trial

Rulings use the owner's scale — **KEEP / SHRINK / DEMOTE / REMOVE** — with one line of reasoning each. "Demote" = keep the information, reduce its presentation. Nothing below was pre-approved; two elements I have previously defended (the elapsed timer, sanctioned as honest in Review 02; the demo caption, praised in Review 04) are ruled against here on visual grounds — honesty was never the question; necessity is.

### Processing — every visible element

| # | Element | Ruling | Reasoning |
|---|---|---|---|
| 1 | Photo card (framed photo) | **KEEP** | The hero and the screen's whole point; correctly shown at natural brightness. |
| 2 | Scan beam | **DEMOTE** | In a still it reads as a neon top border, not activity; it carries zero information at the loudest saturation on the screen — reduce its visual weight; it survives on its motion alone. |
| 3 | Status card (container) | **KEEP** | The right device for stage + expectation; its problems are placement (Lens 2) and contents (below), not existence. |
| 4 | Progress hairline (empty track) | **REMOVE** | An empty grey track communicates nothing and impersonates a divider; it earns a place only while actually filling or pulsing. |
| 5 | Stage title ("Uploading your photo... 0%") | **KEEP** | The one line the screen cannot do without. (Its truthfulness is Review 05 §4-F1, a separate matter.) |
| 6 | Elapsed line ("Elapsed 0:24 · …") | **REMOVE** | A stopwatch on a calm screen: it makes the wait feel metered, and the duration line already tells the time story. Honest, and unnecessary — both can be true. |
| 7 | Expectation ("…processing takes ~2 minutes.") | **KEEP** | The single most useful sentence on the screen; it is what makes a 2-minute wait acceptable. |
| 8 | "You can safely leave the app." | **DEMOTE** | True and important, but it justifies the *button*, not the stage — move it out of the card's text block to caption the "Work in background" action. |
| 9 | "Work in background" pill | **KEEP** | The screen's primary action and the point of the whole redesign; fix its ghost treatment (white on near-white) — a treatment defect, not a necessity question. |
| 10 | Cancel (bare text) | **KEEP** | A real exit, correctly unadorned on a plain canvas; it looks stranded only because of the void beneath it (Lens 2). |

### Home — every visible element

| # | Element | Ruling | Reasoning |
|---|---|---|---|
| 1 | Wordmark ("PeopleGone") | **KEEP** | The brand, once, correctly weighted. |
| 2 | Settings gear | **KEEP** | The one secondary destination; standard placement, no competition. |
| 3 | Job banner (card) | **KEEP** | It is the resumable-job mechanism, not decoration; without it "leave the app" is a promise with no handle. |
| 4 | Banner spinner | **KEEP** | The banner's only activity signal; small, honest motion. |
| 5 | Banner title ("Cleaning photo in background...") | **KEEP** | Names the state in plain words. |
| 6 | Banner subtitle ("Takes ~2 minutes · Tap to return to preview") | **SHRINK** | The duration half duplicates what Processing just said and isn't a remaining-time figure anyway; keep only the destination half (with Review 05 F2's wording fix). |
| 7 | Banner chevron | **KEEP** | The tap affordance; without it the card reads as a notice, not a door. |
| 8 | "Pick a photo" pill + icon | **KEEP** | The product's one action, correctly the most solid element on the screen. |
| 9 | Quota pill — the *container* | **DEMOTE** | A centred floating pill belongs to no column; the fact should sit as a plain line of secondary text in the column's alignment. |
| 10 | Quota pill — the blue dot | **REMOVE** | It mimics a status indicator (live / unread / active) and there is no status; it is the one dishonest *shape* on the screen. |
| 11 | Quota text ("8 of 10 free saves left · Resets 1 Nov") | **KEEP** | Necessary, factual, and now includes the reset date; only its packaging (9, 10) is wrong. |
| 12 | Teaching line | **DEMOTE** | The sentence earns its place on first run; its headline size does not — at ~20sp it out-shouts the hero that demonstrates the same sentence. Body size makes it the demo's introduction instead of its rival. |
| 13 | Demo card (container) | **KEEP** | The screen's anchor — and per Lens 2 it should be substantially *larger*, toward the adopted ~60% hero scale. Keep, and grow. |
| 14 | "Original" / "Cleaned" badges | **KEEP** | On trial and acquitted: without them the split view is ambiguous about which side is which; they are small, translucent, and factual. |
| 15 | Divider + handle | **KEEP** | The best-built element on either screen; the arrows are also the instruction (see 17). |
| 16 | Caption icon (blue hand) | **REMOVE** | Clip-art. It is the only element on either screen that would look at home in a template, and it teaches nothing the handle doesn't. |
| 17 | Caption text ("Drag divider to preview clean · Real app output") | **SHRINK** | Keep "Real app output" — the trust fact. Drop the drag instruction: the handle's arrows already teach it, and a permanent instruction for a one-time discovery is permanent noise. |

**Audit summary:** 28 elements ruled on — 16 KEEP, 3 SHRINK, 5 DEMOTE, 4 REMOVE. The removals are small (a hairline, a stopwatch, a dot, an icon) and that is precisely the point the owner is making: the screens are not cluttered with *features*, they are cluttered with *presentation* — and simultaneously under-filled in the large. Shrink the presentation, grow the hero, anchor the bottom, and both screens become what their concepts already are.

---

## Direction amendments from this supplement (DESIGN_DIRECTION §11)

- **D11 — Element rulings (standing):** (a) S6's status card shows stage + expectation only — no elapsed timer, no static progress track (a track appears only while filling with real % or pulsing indeterminate); (b) Home's quota is a plain secondary-text line in the column — no pill container, no status dot; (c) the demo caption is provenance only ("Real app output") — no instruction text, no icon; (d) the banner subtitle is the destination only. These supersede earlier approvals where they conflict (Review 02's elapsed sanction was an honesty ruling, not a necessity ruling; the owner's necessity audit governs presentation).
