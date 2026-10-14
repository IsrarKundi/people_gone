# Review 09 — Phase D Copy Verdict (Reflection Warning · Fix Action · Brush Guide)

**Date:** 2026-10-15
**Reviewer:** UI/UX design lead (copy authority, §10)
**Material:** The three Phase D strings as shipped in `lib/core/strings/app_strings.dart` (`resultReflectionWarning`, `resultReflectionFix`, `brushReflectionGuide`), verified verbatim against the code — not against a paraphrase. Facts judged as fixed by the brief: the warning fires only for a likely leftover reflection of a *removed* person (keeper reflections never trigger it); the brush opens with the first detected region outlined as a guide only — the outline is never part of the mask; the user still paints.
**Governing rulings:** X12–X14 (reflections are never items, never promised; the brush is the failure path).

**Verdict: ALL THREE STRINGS APPROVED AS-IS. No rewrites.** The interim wording the build wrote in the plainest factual register is the wording I would have written; it goes in the record as final.

---

1. **"A reflection of a removed person may still be visible."** — Approved. The subject is exact: a *removed* person's reflection, which is the only thing that can trigger the line, so it never cries wolf about the keeper. "May" is the correct hedge for a probabilistic detection — the line warns, which is all Phase D is permitted to do under X13; it promises nothing about automatic removal, carries no alarm, and matches the Result screen's factual register.
2. **"Fix with brush"** — Approved. A short action label that names the path, not an outcome — the same convention as "Remove painted area" and the existing "Brush fix" entry it sits beside. What the brush actually demands of the user (their own painting) is stated by the guide text at the moment of use, which is where that fact belongs.
3. **"The outlined area is where a reflection may still be visible. Paint over it to remove it."** — Approved. The first sentence frames the outline precisely as a location aid ("where … may still be visible") — important, because the outline is a guide and never part of the mask, and the text never claims it selects anything. The second sentence hands the user their actual job in the brush hint's own imperative register. Its one compression — "paint over it to remove it" elides the Apply tap — is honest in context: the same view's primary ("Remove painted area") closes that loop in front of the user.

**Disposition of X14's gated hint revision:** my expansions doc proposed, gated on evidence, revising the S5 hint to "— including its shadow or reflection" if reflection handling shipped. Phase D shipped warn-only, and the build instead communicates contextually — the guide text appears only in a session where a region was actually detected. That is the better solution: the settled hint would have mentioned reflections in *every* brush session, most of which contain none. **The X14 hint revision is NOT adopted; the contextual guide supersedes it. The brush hint stays exactly as settled.**
