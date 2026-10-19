# S8 Paywall — Design Brief (build specification)

**Date:** 2026-10-19 · **Author:** UI/UX design lead (§10 authority) · **Builder:** Antigravity (Task 2, audit handoff) · **Verifier:** Muse
**Status of facts:** pricing and free-tier facts below are SETTLED product facts (requirements §9) — implement them exactly; do not re-decide, round, or re-word them. Copy wording is the design lead's and is specified verbatim in §4 — create the string keys exactly as given. Layout, tokens, and states are specified; anything not specified here follows the existing design system (DESIGN_DIRECTION.md, one-card-language D12, photo-frame system).

**Settled facts (not design choices):** Annual $19.99/year · Monthly $4.99/month · Lifetime $34.99 one payment. Free tier: 10 full-resolution saves per calendar month, no watermark ever, unlimited previews. Pro fair-use cap: 300 saves/month. No trial. No weekly plan. No discounts, no countdowns, no urgency devices. Prices are displayed ONLY from `PurchaseService.offerings()` (`StoreOffering.priceString`, localised by the store) — never hard-coded anywhere in app code. Entry points (already decided, do not add more): (a) Save tapped on Result with 0 free saves (blocked save), (b) Home saves-line tapped at 0 saves. S8 is never shown before the user's first successful result, and the result preview is never blurred or watermarked anywhere, including inside S8's hero.

---

## 1. Layout (top → bottom, single column, `screenPadding` margins)

Existing tokens only (`app_sizes.dart`, `app_text.dart`, theme palette). No new colours, no raw dimensions.

1. **Close row** — a single close (×) icon button, top-right, no title text in the bar. Semantics/tooltip: key `paywallClose` (§4).
2. **Hero** — the photo treatment in §2, in `PhotoFrame` (photoRadius), full content width.
3. **Headline** — `displayBrand` (Poppins display role), left-aligned, key `paywallHeadline`.
4. **Subline** — body size, secondary colour, key `paywallSubline`.
5. **Arrival-context line** — body size, primary text colour. ONE line, chosen by the state rules in §5. This slot exists in every free-user state; it is never empty for a free user.
6. **Plan rows** — three selectable cards (§3), `radiusLg`, one-card language (surface + neutral hairline border), vertical gap `s.md`. Annual first, Monthly second, Lifetime third.
7. **Selection caption** — caption size, secondary colour, directly above the CTA; wording depends on the selected plan (§4). This caption is the renewal/one-payment disclosure — it is part of the design, not optional fine print.
8. **CTA** — the app's existing `PrimaryButton`, full width, key `paywallCta`. Behaviour in §6.
9. **Restore** — a quiet text button under the CTA, key `paywallRestore`.
10. **Fine print** — caption size, secondary colour, the three lines in §4, at the bottom. If the screen scrolls on small devices, the fine print scrolls with the content; the CTA is NOT pinned over it (no floating purchase bar — the whole offer must be readable as one page).

Accessibility: each plan row is ONE selectable control; its spoken label combines name, descriptor, price (when present), and selected state. At 1.30 text scale a row's price may wrap under the descriptor — nothing truncates, nothing overlaps.

## 2. Hero — two arrivals

**(a) Arrival WITH the user's cleaned photo (blocked save, from Result).** The hero is built from THAT photo pair: a **static before/after split** in `PhotoFrame` — left half original, right half cleaned, the app's compare divider line and handle glyph at the centre, exactly as the Result compare looks at rest. It is NOT interactive (the interactive compare lives on Result; the hero's job is to recall what is waiting to be saved). Height follows the photo's aspect within the frame system (D13 — frames hug photos, clamped as in Processing). **No caption** — it is obviously the user's own photo. The photo is shown clean and unblurred, at full quality.

**(b) Arrival WITHOUT a photo (Home saves-line at 0).** The hero is the app's demo pair (café before/after, `assets/images/demo_original.jpg` / `demo_result.jpg`), in the identical static split treatment, with the established caption **"Real app output"** (existing key `demoCaption`) — the demo-honesty rule (X17): the pair is a real output of the shipped pipeline for exactly the capability it shows. No other imagery may be used — no stock photos, no illustrations, no gradient placeholder.

In both arrivals the hero is a still. No motion is applied to it (see §7).

## 3. Plan hierarchy and the price slots

- **Annual is the anchor.** It is pre-selected on arrival; its card carries the badge **"Best value"** (key `paywallBestValue`) — a small pill above the plan name, primary-coloured text on the palette's primary-container tone (map to existing palette roles; no raw colour). Its price renders in `titleMd`; the secondary rows render theirs in `bodyLg` semibold. The badge is factual — both subscription prices are visible in the same screen and prove the comparison — and it is the ONLY badge on the screen.
- **Row content.** Left column: plan name (`labelLg` semibold; keys in §4) over its descriptor (caption, secondary colour). Right column: the price slot. Rows are radio-selectable: tapping a row selects it (selection behaviour in §7).
- **Selected state:** border becomes the primary colour at 2px (state colour is permitted by D12); unselected rows keep the neutral hairline at 1px. Exactly one row is selected at all times in the loaded state.
- **Rows bind to offerings by `period`** (`year` / `month` / `lifetime`). The price slot shows that offering's `priceString` **verbatim**. If a period is missing from the offerings, that row is hidden — a price is never invented, estimated, or remembered from a previous launch. If NO offerings exist, the screen is in the unavailable state (§5).
- **Layout stability:** rows keep a fixed minimum height (content + `s.lg` vertical padding) whether or not prices have loaded, and the price slot reserves its line box — when prices arrive, nothing on the screen moves.
- **Deliberate omission:** there is NO per-month equivalent line ("$1.67/month") on the Annual row. `StoreOffering` carries only a localised price string, not a number — a monthly equivalent cannot be derived honestly from it, so it is not shown. Do not add a numeric price field to work around this without a design-lead ruling.

## 4. Copy — exact keys and wording (create verbatim in app_strings.dart)

| Key | Wording |
|---|---|
| `paywallClose` | `Close` (semantics/tooltip only) |
| `paywallHeadline` | `10 saves a month becomes 300` |
| `paywallSubline` | `Every save is full resolution, with no watermark — free or Pro.` |
| `paywallArrivalBlocked` | `You've used all 10 free saves for @month. They return on 1 @nextMonth.` |
| `paywallArrivalSavesLeft` | `You have @count of 10 free saves left for @month.` |
| `paywallPlanAnnual` | `Annual` |
| `paywallPlanMonthly` | `Monthly` |
| `paywallPlanLifetime` | `Lifetime` |
| `paywallPerYear` | `Per year` |
| `paywallPerMonth` | `Per month` |
| `paywallOnePayment` | `One payment` |
| `paywallBestValue` | `Best value` |
| `paywallCaptionAnnual` | `@price a year · Renews automatically · Cancel anytime in Google Play` |
| `paywallCaptionMonthly` | `@price a month · Renews automatically · Cancel anytime in Google Play` |
| `paywallCaptionLifetime` | `@price · One payment · No renewal` |
| `paywallCta` | `Continue` |
| `paywallRestore` | `Restore purchases` |
| `paywallPricesUnavailable` | `Prices can't be loaded right now.` |
| `paywallTryAgain` | `Try again` |
| `paywallPurchaseFailed` | `The purchase couldn't be completed. You have not been charged.` |
| `paywallFineFree` | `Free plan: 10 full-resolution saves a month.` |
| `paywallFineCap` | `Pro: up to 300 saves a month.` |
| `paywallFinePayment` | `Payment is handled by Google Play.` |
| `paywallProHeadline` | `You're on Pro` |
| `paywallProPlan` | `Your plan: @plan` |
| `paywallProNote` | `You can save up to 300 photos a month.` |

Notes: `@month` / `@nextMonth` are computed month names (the standing computed-date rule — never a hard-coded month, never the word "soon"). `@price` is the offering's `priceString` verbatim. `@plan` (Pro state) is the offering/store title of the active plan. The headline is a fact about the quotas, not a slogan — set it in `displayBrand` and let the numbers carry it.

## 5. States (all must be built; captures required for each, §8)

1. **Free, blocked save, with photo** — hero (a); arrival line = `paywallArrivalBlocked`; plans as §3.
2. **Free, deliberate arrival (saves left)** — hero (b) unless a photo context exists; arrival line = `paywallArrivalSavesLeft` with the real count. The screen must never pretend this user is blocked.
3. **Prices unavailable** (offerings() errors or returns empty — includes the entire interim period, §6) — hero and headline/subline as normal; plan rows render name + descriptor ONLY (price slots empty, row heights unchanged); the CTA and selection caption are REPLACED by the line `paywallPricesUnavailable` + a `paywallTryAgain` text action that re-calls `offerings()`. Restore remains. Nothing about this state may look broken — it is designed, not an error screen.
4. **Already Pro** (`isPro` true on arrival) — the sales layout is replaced: no plan rows, no CTA. Headline slot shows `paywallProHeadline`, then `paywallProPlan`, then `paywallProNote`; hero (b) treatment or none (use hero (b) if no photo context; with a photo context use hero (a)); Restore remains; close returns. Never sell to someone who already bought.
5. **Purchase in flight** — CTA enters the PrimaryButton labelled-loading mode (spinner + "Continue" stays visible — the Review 07 rule); rows and close are disabled while the store sheet is up (the exit rule D15 yields to the store's own sheet, which the user can always cancel at the store level).

## 6. Dismiss and CTA behaviour

- **Dismiss:** the × and system back both close S8 with no confirmation, no guilt copy, no "are you sure", no retained-selection tricks. From a blocked-save arrival, dismissing returns to Result with the cleaned photo intact and still previewable — the user loses nothing by looking at this screen.
- **CTA — the honest interim (NOW, RevenueCat unwired):** `offerings()` cannot succeed, so the screen lives in State 3 and there is NO tappable purchase path at all. This is the interim behaviour, and it is honest by construction: no prices are shown (never the settled numbers typed into the app), no purchase is simulated, no success state exists to fake. **S8 is not shippable to production until the loaded state is the reachable one** — the wiring task (Phase 3) is what changes that, not any change to this screen.
- **CTA — post-wiring behaviour (build the seams now):** tap → `purchase(selectedOffering.id)` → the STORE's own purchase sheet presents price and confirmation (the app never builds its own payment confirmation and never shows success before the service confirms). On success (`isPro` becomes true): if the arrival was a blocked save, return to Result where the save can now proceed; otherwise close S8 back to the entry context. NO celebration, no confetti, no success choreography (§9 Q6) — the state simply changes. On a user-cancelled store sheet: stay on S8, show nothing. On an error result: stay on S8 and show `paywallPurchaseFailed` as a quiet line above the CTA. Restore → `restore()`; on success-to-Pro, transition to State 4 in place; on failure, the same quiet failed line.

## 7. Motion (house rules — motion tokens from the animation pass)

- Screen entry/exit: the standard app transition (300 ms). Nothing on S8 gets a bespoke entrance.
- Row selection: border/colour crossfade + press dip, fast token (180 ms), no overshoot. Selection caption crossfades when the plan changes.
- State swaps (plans ↔ unavailable ↔ Pro): standard crossfade. CTA loading: the labelled-loading mode.
- The hero is a still — no sweep, no auto-compare animation (the teaching sweep belongs to Home's demo and Result; a paywall is a decision surface, not a demo).
- Forbidden here as everywhere: pulsing or glowing CTA, animated price counters, countdown anything, confetti, sparkles. Reduced motion: all of the above collapses to short fades per the standing rule.

## 8. Evidence required with the build

Harness captures, light + dark, for: State 1 (blocked, café-pair hero from a fixture result), State 2 (deliberate, saves left), State 3 (unavailable), State 4 (Pro) — plus the loaded plans state at 1.30 text scale. Fixtures use a fake `PurchaseService` whose offerings carry the settled prices as fixture data (fixtures are test data; the rule binds app code only). The verifier checks captures against this brief section by section.

**Not in scope / do not build:** any trial or introductory-offer UI; strikethrough "was" pricing; a feature checklist beyond the factual lines specified (Pro's v1 benefit is the save cap — do not invent "priority processing", "early access", or any other benefit); email capture; a manage-subscription screen (Google Play handles it; the caption says so); any new entry point into S8.
