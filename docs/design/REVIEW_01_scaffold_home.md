# Review 01 — Task 1.1 Scaffold, Home (empty state)

**Date:** 2026-10-13
**Reviewer:** UI/UX design agent
**Material reviewed:** Owner screenshot, iOS Simulator (iPhone 11 Pro Max, iOS 26.2), light mode — AppBar "PeopleGone", in-body heading "PeopleGone", saves line "10 of 10 free saves left this month.", centred teaching line, no primary action (picker not yet built — expected at Task 1.1).
**Verdict: REJECT — two shell-level fixes required before the working loop (picker → processing → result) is built on top of this scaffold.** The fixes are small, but they live in `AppScaffold` / Home's column — the pattern S9 and S10 will copy — so they are cheaper now than after real screens land. Nothing in this verdict questions the scaffold's honesty: no fake button was shipped to fill the gap, and that restraint is approved.

**What is right (keep):** scaffold background matches the `background` token; the saves copy is exact and stated before any work (FR-25 register); the teaching line is the specified sentence, unembellished; no upsell, no clutter, no stock illustration, no gradient/AI chrome. Type colour hierarchy (dark heading / secondary supporting lines) is in the right register.

---

## Ruling 1 — Duplicated product name: the wordmark lives in the AppBar, and only there

**Finding:** "PeopleGone" appears twice — centred as the AppBar title, then again as a large bold in-body heading. This fails DESIGN_DIRECTION §8 ("nothing on screen could be mistaken for another app's screen"; a doubled wordmark is the stock-template header pattern) and contradicts the S1 layout spec, which never had an in-body heading.

**Correct pattern (binding, now folded into DESIGN_DIRECTION §3 and §4-S1):**

1. The AppBar **is** the wordmark: "PeopleGone" in Inter 800, `titleLg`, `textPrimary` (R5), **left-aligned**, with the Settings icon button (48dp target) at the right. That is the only place the product name appears on Home — and the same rule applies to S9/S10: the product name appears exactly once per screen, in the app bar.
2. The in-body heading is **deleted**, not restyled. Home's column is: saves indicator → primary button → history / empty-state content. There is no H1 on Home.
3. The centred AppBar title is also rejected: a centred title with no trailing action is the default template look. Left-aligned wordmark + trailing Settings action is the pattern.
4. The Settings icon ships with this fix, wired to the S10 route shell. The shell may initially contain only the rows that are real today (e.g. Version); rows arrive with their features. An unwired/dead icon is itself a reject — no fake actions (Conventions §13).

## Ruling 2 — Vertical rhythm: fix the composition now; the empty middle is a layout bug, not a scaffold pass

**Finding:** After the (to-be-deleted) heading and saves line, the screen is a large void, with the teaching line floating at the vertical centre of the remaining space, then a second void below it. The gaps are spacer-driven, not token-driven — they are sizes that do not exist in `AppSizes`, which Conventions §6.4 forbids ("a size that is not in the scale does not exist"). Two disconnected islands and a floating sentence read as a placeholder screen, however honest the copy is.

**Ruling:** the scaffold must already carry the **final** Home composition with the action area in its final position. Specifically:

1. Home is a **single top-anchored column**. All vertical gaps come from `AppSizes` tokens. No `Spacer`, no `Center`-widget vertical centring of content blocks, anywhere on S1.
2. Order and spacing: AppBar → saves indicator (`lg` below the app bar) → **PrimaryButton "Pick a photo"** (`lg` below the saves indicator) → empty-state/history region.
3. The button's position is therefore defined **now**, and the next Home milestone screenshot must show the real, wired button (the working-loop task is already underway — the button opens the system picker; it is not a reserved grey box, and a disabled placeholder button will be rejected under the no-fake-actions rule). This review accepts the button's absence *only* in the screenshot under review, because Task 1.1 predates the picker.
4. Empty state (State A): the teaching line sits **in flow**, `xxxl` (32) below the button, text centre-aligned within the column, set in `bodyLg` / `textPrimary` (it is the product explanation — primary content, not a hint; in the screenshot it renders in a muted grey, which demotes it). The space below the line stays empty. That emptiness is correct and expected on first run — what was wrong was the line floating in the middle of it, detached from the column it belongs to.
5. No "History" section header in the empty state (State A is wordmark-column + the one line, per spec). The header appears with the first history item.
6. The saves indicator ships its **thin determinate bar** with the text line from this fix onward (DESIGN_DIRECTION §4-S1 already specifies text + bar; the screenshot shows text only). The bar is a display of real state (10 of 10), not an action, so it belongs in the scaffold — its absence makes the indicator read as a caption rather than the app's meter.

## Ruling 3 — Other template tells and gaps in this screenshot

1. **Wordmark weight:** the AppBar title renders at a medium/semibold weight. R5 specifies Inter 800. After Ruling 1's consolidation, verify the surviving wordmark is 800 / `titleLg`.
2. **Dark mode not evidenced.** The direction (§8 checklist) requires every screen checked in light **and** dark. This milestone supplied light only. The next screenshot set for Home must include dark mode and a 1.30 text-scale pass. Not a reject ground for a scaffold screenshot; it is a reject ground for the Home milestone proper.
3. **Nothing else generic found:** no card-ification, no FAB, no drawer, no banner. The restraint is the right instinct — keep it.

## Required changes (for the build agent, in order)

1. `AppScaffold` app bar: left-aligned Inter 800 wordmark + Settings icon → S10 shell route. Remove the in-body heading from Home. (Ruling 1)
2. Home column rebuilt top-anchored on token gaps only; saves indicator gains its bar; teaching line moves in-flow below the button position, `bodyLg`/`textPrimary`, centre-aligned text. (Ruling 2)
3. With the working loop: real "Pick a photo" `PrimaryButton` in the defined position, opening the system picker. Next Home evidence: light + dark + 1.30 text scale. (Rulings 2.3, 3.2)

**Direction changes folded in:** DESIGN_DIRECTION.md §3 (app-bar pattern + one-name-per-screen rule), §4-S1 (State A placement, saves bar, no History header when empty), §8 (two new checklist items). The direction's intent did not change; its S1 wording ("one centred line") was ambiguous about *placement* and has been tightened — that ambiguity is on the direction doc, not the builder.
