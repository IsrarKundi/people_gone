# Review 05 — New Home + New Processing (owner-screenshot pass, reframed)

**Date:** 2026-10-14 (reframed the same day at the owner's direction)
**Reviewer:** UI/UX design lead
**Material:** The owner's own two screenshots from his running build (iOS Simulator, light theme): new Processing mid-job (mosque photo, elapsed 0:24) and new Home with a background job running. Implementation commits are not on origin/main yet (main at `780e23a`), so this is the screenshot pass; the harness full pass is still owed (§5). **Design review, not launch approval — the owner's own-eyes verdict overrules it.**

**How this review is framed (owner's instruction):** visual and compositional judgement first, under three lenses — (1) do the screens actually *look* good, (2) density and balance, (3) an element-by-element audit. Functionality is not judged here. The factual/copy findings from the first pass are kept, demoted to §4.

**Verdicts: both screens — REJECTED on composition.** The concepts are approved (living canvas; Option A home), most elements individually earn their place, and nothing here is dishonest. But both screens share the same unfinished signature: **everything is piled into the top half-to-two-thirds and the eye then falls into a void.** That is the exact failure the owner has now killed three times (first-run Home, with-history Home, and the darkroom's dead canvas) — a redesign that reproduces it in a new costume has not finished its job. The fix lists are bounded and specific; neither screen needs a new concept.

The amateur tells, named plainly because the owner asked for bluntness: a white button on a near-white background (Processing); photo slivers peeking out from behind a floating pill (Processing); a settings-style stopwatch in the middle of a "calm" card (Processing); an empty grey hairline posing as a progress bar (Processing); a lone centred pill that belongs to no alignment column (Home); a blue border that reads as a focus ring (Home); a clip-art hand icon (Home). Professional screens do not have these. Remove them and both screens cross the line.

---

## 1. Processing — REJECTED on composition (concept approved)

**Lens 1 — does it look good?** In pieces, yes; as a composition, not yet. The framed photo at natural brightness is handsome, the status card is clean, the type is well-set. But the junction where photo card, status card and action pill meet is fussy, and the lower third is a different, emptier screen than the top two-thirds.

- **P1 (major) — the terminal void.** Below Cancel sits roughly a quarter of the screen of bare porcelain. The composition has a top anchor and no bottom anchor: photo, card, pill, Cancel — then nothing. It reads as a screen that ends early, not a screen at rest.
- **P2 (moderate) — the double overlap.** The status card overlaps the photo card, and the "Work in background" pill *also* overlaps the photo card, whose bottom corners peek out as photo slivers at the pill's left and right edges. One overlap is a design device; two stacked overlaps with the photo peeking through a third gap look like a rendering accident.
- **P3 (moderate) — the ghost pill.** "Work in background" is a white pill on a `#F8F9FA` background: its lower edge dissolves into the canvas and only its shadow defines it. A primary action should be the most solid thing on the screen; this one is the faintest.
- **P4 (moderate) — the status card's grey wall.** Title, then three facts (elapsed / ~2 minutes / leave-the-app) set as one two-line grey paragraph. It reads dense against the otherwise airy card, and the information is grouped wrong (see element audit): the leave-the-app line justifies the *button below the card*, not the stage line inside it.

**Lens 2 — density and balance.** Top-loaded and bottom-empty, as P1. The photo card is also larger than the composition needs: at this aspect it consumes ~60% of the height and still leaves the void, because nothing is anchored to the bottom. The adopted Option 1 structure was a **bottom tray** — the fix is to honour it: pin the status card + actions as a bottom cluster above the safe area, let the photo card take the space above it, and let any spare space fall *between* photo and tray, where it reads as gallery air, instead of below Cancel, where it reads as an absence.

**Lens 3 — element audit (Processing):**

| Element | Ruling |
|---|---|
| Scan beam | **Keep** — but know that in a still it reads as a neon top border on the photo card. Acceptable because it moves; it is the screen's only sign of life. (Honesty condition from the first pass stands: indeterminate only.) |
| Photo card | **Keep** — the hero, correctly un-dimmed. Its bottom edge must stop colliding with two other elements (P2). |
| Progress hairline (empty track) | **Remove in this state** — an empty grey track at the card's top edge reads as a stray divider, not progress. It earns its place only while it is actually filling (real upload %) or pulsing (indeterminate); a static empty line is clutter. |
| Stage title ("Uploading your photo... 0%") | **Keep the element** (its truthfulness problem is §4-F1). |
| Elapsed timer ("Elapsed 0:24") | **Remove from the card.** It remains *honest*, but visually it is a stopwatch: it makes a calm screen feel metered and anxious, and the "~2 minutes" expectation already tells the time story. This is the single most "utility app" element on the screen. |
| Expectation + leave-app lines | **Split and demote** — "~2 minutes" stays with the stage line, short. "You can safely leave the app." moves down to caption the "Work in background" button it justifies. As one grey paragraph, both are weakened. |
| "Work in background" pill | **Keep the action, fix the treatment** (P3): give it a defined edge or fill so it separates from the canvas; end the photo-sliv­er overlap (P2). |
| Cancel (bare text) | **Keep** — correctly unadorned on a plain canvas (the A8 pill rule governs photo surfaces; this isn't one, see first pass). It looks like an afterthought only because of the void beneath it; bottom-anchoring (P1) fixes its reading without changing the element. |

## 2. Home — REJECTED on composition (concept approved)

**Lens 1 — does it look good?** The ingredients are right and the palette is coherent; the *proportions* are wrong. This is Option A with its hero shrunk to a supporting role.

- **H1 (major) — the hero is too small, so the bottom half is empty.** The adopted Option A specifies a hero canvas at ~60% of screen height. The built demo card occupies roughly 30%, sits *last* in the stack, and below it lies ~45% of the screen as bare porcelain. The research's own diagnosis of the old Home was "the 70% white void"; the redesign has reduced it, not eliminated it — the eye still runs out of content mid-screen and the page still reads as ending early.
- **H2 (moderate) — the centred quota pill belongs to no column.** Wordmark left, banner full-width, Pick full-width, teaching line left, demo full-width — and between them a small pill floating at centre like a toast that wandered in. It breaks the screen's one alignment story. The blue dot inside it is also a small lie of form: it mimics a status indicator, but there is no status — nothing is on, active, or unread. Remove the dot; align the pill with the column (or centre the *whole* footer zone deliberately — one alignment story, not two).
- **H3 (moderate) — the teaching line is set like a headline and competes with the hero.** It is the largest text on the screen after the wordmark, larger than anything in the demo card, and it says in words exactly what the card below it shows in pictures. The sentence earns its place on a first-run screen; its *size and placement* don't. Demote it to body size and it becomes the demo card's introduction instead of its rival.
- **H4 (minor) — the banner's blue border reads as a focus ring.** It is the only coloured-border element on the screen, and the effect is "selected text field", not "active job". The spinner already signals activity; give the banner the same neutral border as every other card.

**Lens 2 — density and balance.** A compressed top cluster (banner, pill, pill, paragraph, card — five containers in the top ~55%) over an empty bottom ~45%. Restoring the hero's scale (H1) is the main rebalance: a dominant demo card absorbs the space the void currently wastes, and the top cluster can loosen its gaps in the room that creates.

**Lens 3 — element audit (Home):**

| Element | Ruling |
|---|---|
| Wordmark + settings gear | **Keep** — clean, correctly singular. |
| Job banner | **Keep** — it is the §9-Q1 resumable row realised and the mechanism that makes "leave the app" true. Fix only its border (H4) and subtitle wording (§4-F2). |
| Banner subtitle ("Takes ~2 minutes · Tap to return to preview") | **Keep, shortened by the F2 fix** — the duration half earns its place; the destination half must name the real destination. |
| Pick pill | **Keep** — modern, legible, correctly dominant among the actions. |
| Quota pill | **Keep the fact, fix the form** (H2): left-align with the column, remove the status dot. Its quietness is right; its placement is not. |
| Teaching line | **Keep the sentence, demote the type** (H3). |
| Demo card badges ("Original" / "Cleaned") | **Keep** — they label the divider's two sides; without them the split is ambiguous. Correctly small, correctly translucent. |
| Divider + handle | **Keep** — the best-built element on either screen. |
| Demo caption ("Drag divider to preview clean · Real app output") | **Keep the text, remove the hand icon** — the two facts (how to use it; that it's real output) both earn their place. The blue hand glyph is the one piece of clip-art on either screen and the closest thing to template decoration here. |
| "Notify me when done" | **Absent — correct** (owner's ruling, honoured). |

## 3. What would make both screens pass

Bounded, in order: (1) anchor Processing's status/action cluster to the bottom and end the double overlap (P1–P3); (2) clear Processing's card — no empty track, no stopwatch, split the grey wall (P4 + audit); (3) restore Home's hero toward the adopted ~60% scale so the screen composes to its bottom edge (H1); (4) one alignment story on Home — quota pill into the column, dot removed (H2); (5) teaching line demoted to body size (H3); (6) banner border neutral, caption icon removed (H4 + audit). None of this touches the concepts, the copy facts, or the flows — it is proportion, anchoring and restraint.

## 4. Factual / copy findings (from the first pass — secondary, still standing)

- **F1 (required) — stage label vs real state.** "Uploading your photo... 0%" at elapsed 0:24: either bytes have not started moving (then the honest stage is the waiting/connecting phase, not "Uploading") or they are moving too slowly for 0% to sit beside a "~2 minutes" promise without reading as *stuck*. Per the owner's real-states-only rule: the % shows only while bytes transfer; the pre-transfer phase gets its own factual label. Fix the label logic, not the number. (This and the empty-track ruling in §1 are the same wound seen from two sides.)
- **F2 (required, minor) — banner wording.** "Tap to return to preview" names a screen that doesn't exist; the job is still running. "Tap to view progress" (or "Tap to return to your photo").
- **Closed by this redesign, for the record:** Review 02's F2 interim ("keep the app open") is retired because resumable jobs + the Home banner shipped — an implementation change, as its closure condition required. No "Notify me" was built. The hero is the cafe pair. Cancel's bare text on the plain canvas does not violate A8 (that rule governs photo surfaces).

## 5. Still owed — the full pass (when the implementation lands on main)

Light + dark harness renders of both screens; 1.30 text scale (status card and quota pill are the truncation risks); the with-history hero state (latest clean as hero + tray — no evidence exists yet); banner **done** and **failed** states (failed must read as a state with the no-charge fact, never a dead end); Processing's post-upload stage; Cancel's tap target and no-charge dialog in the new layout; the beam in dark mode. These composition verdicts stand unless the full pass contradicts them.

## 6. Reconciliations recorded in DESIGN_DIRECTION.md (§11)

- **D7** — Home/S9 divergence (owner-approved, Home only).
- **D8** — Processing treatment: living canvas supersedes the darkroom approval for S3/S6; beam sanctioned as indeterminate-only.
- **D9** — Background copy rule + Review 02 F2 closure.
- **D10** — **No terminal void (new, from this review):** a primary screen whose content ends in unstructured empty space in its bottom quarter is a composition reject, whatever its elements' individual quality. Primary screens anchor top *and* bottom (or centre the hero); spare space belongs between elements, not after the last one.
