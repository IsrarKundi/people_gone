# Review 03 — Confirmation Pass on the Review 02 Fixes

**Date:** 2026-10-14
**Reviewer:** UI/UX design lead
**Material reviewed:** Post-fix renders (refreshed in `~/workspace/peoplegone/design/review02/`: S6, S7, S7-compare, S10) against fix commits `4f9fd29` (F1), `fae6881` (F3+F7), `8eff791` (F4), `97205b8` (F5), `c0ecdeb` (F6), `64f501b` (F8+A6); F2 verified no-change. Build state as handed over: origin/main `fae6881`, analyze clean, 63/63 tests.
**Verdict: ALL FIXES CONFIRMED. The Review 02 round is CLOSED.** The working loop stands approved as the development build (this remains a dev-build approval, not a launch approval — the evidence-owed list at the end of Review 02 still applies before any store build).

---

## Per-fix confirmation

- **F1 — photo surround: CONFIRMED.** S6 now sits on the `background`-token surround with the dim blended onto the photo pixels only. One surround across S6/S7/S9 — the "two different apps" problem is gone. (Verified in `processing_view.dart`: scrim via `colorBlendMode.srcATop` on the image, scaffold surround untouched.)
- **F1 follow-on — the Cancel pill: CONFIRMED (the item put to me).** With the full-screen grey gone, bare white Cancel text would vanish whenever it lands on the light surround. The builder's solution — Cancel as a `photoChrome` pill (R1 treatment: `photoChromeBg` fill, `photoChromeFg` label, pill radius) — is the right call, and it's now the recorded pattern (Direction amendment, below): **any text action on a photo surface that can land off the photo band rides in a photoChrome pill.** In the render it reads as deliberate chrome, legible on photo and surround alike. The visual pill is compact; its tap target is the padded Material target (48dp), so the minimum-target rule holds. No change requested.
- **F2 — expectation copy: CONFIRMED no-change.** The live S6 line already matches the approved interim wording ("This can take a few minutes. Keep the app open while we work."). The standing condition is unchanged: this copy is reverted when GPU processing + resumable jobs land (Review 02, F2).
- **F3 — S7 chrome: CONFIRMED.** Close/compare are now 48dp `photoChrome` discs pinned to the photo band's top corners, on the photo — the oversized floating grey discs are gone; the top of S7 now looks like it belongs to the same app as S6.
- **F4 — disclosure link: CONFIRMED.** "Report this result" now wraps as one unit onto its own line. The orphaned "result" is gone. (The line now breaks as "…deleted from server / · Report this result" — the leading separator on the second line is acceptable typography for a unit wrap.)
- **F5 — ConsentSheet variants: CONFIRMED.** Read-only variant is a single Close; the in-flow consent variant is unchanged (Continue/Cancel), and widget tests cover both variants. Two-dismiss is gone.
- **F6 — shared HistoryGrid: CONFIRMED.** Home's history section is now the first row of the same 3-column grid S9 uses (`c0ecdeb`). One component, two surfaces, as decided in §9 item 3.
- **F7 — compare pills: CONFIRMED.** In compare mode, "Before"/"After" pills sit below the chrome row on the photo; nothing overlays the close/compare controls. The slider state now reads cleanly at a glance.
- **F8 + A6 — Settings: CONFIRMED.** The plan line carries the computed reset date ("7 of 10 free saves left — resets 1 Nov"), and the provider row's label/value collision is resolved by the minimum gap (the label wraps to two lines at this width with the value trailing — acceptable settings-row behaviour, and the robust outcome at 1.30 scale).

## Direction amendment recorded

- **A8** (§4-S6 / §5 PhotoSurface): text actions on a photo surface that can land off the photo band (S3/S6 Cancel is the case) use the `photoChrome` pill treatment (R1). Bare text on a photo surface is a reject — legibility must not depend on where the photo band happens to fall.

## State of the product after this round

Approved: S1 (both states, light + dark + 1.30), S2, S6, S7 (+compare), S9 (grid + detail), S10. Not built, by phase, and explicitly outside this approval: **S4 Proposal** (G1 — lands with the Phase 2 gateway analyse/confirm API; the post-hoc keeper re-run remains a recovery, not a substitute), **S5 Brush** (G2), **ghost notice** (G3 — waits on a ghost flag in the API), **S8 Paywall** (Phase 3 — empty binding shell only). Evidence still owed before a store build: dark renders for S6/S7/S9/S10, 1.30 renders beyond S1, Delete confirm dialog. The next design milestone is the S4 review when the gateway API lands — that screen, not any of these, is where the product's defining promise gets judged.
