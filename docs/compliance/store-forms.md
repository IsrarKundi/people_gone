# Store forms — data behaviour record (Requirements CMP-04)

Updated in the same change as any data-behaviour change (AGENTS.md).
Full form answers are finalised in Phase 4 (Task 4.1); this file tracks
the app's actual behaviour as built.

## Current behaviour (dev build, Phase 1)

| Data | Behaviour |
|---|---|
| Photos | Only the single photo the user picks (system picker; no library access, no media permission) is uploaded, over TLS, to PeopleGone's own processing server (`API_BASE_URL` in build config) when — and only when — the user has accepted the versioned consent sheet (§11.2A). The dev server processes the request in memory and returns the cleaned photo; it stores nothing. Production retention (delete on delivery / ≤ 24 h) lands with the Phase 2 gateway (§7.4). |
| On device | History of saved results + a free-saves counter + the consent record live only in app storage on the phone. Nothing is synced. The user can delete any history entry (its stored photo copy is deleted with it); the copy in the device photo library is separate and unaffected. |
| Analytics / tracking | None. No third-party SDKs, no ads, no accounts (CMP-12). |
| Saves to library | A cleaned photo enters the device photo library only when the user taps Save (add-only platform flow). Location metadata is not added by the app; the worker's output carries no GPS (§5 FR-15 — server-side guarantee, verified with the gateway in Phase 2). |
| Sharing / reports | Share uses the system share sheet on the saved file (user-directed). "Report this result" opens the user's mail app addressed to the support email from build config with job counts only — the photo is attached only if the user adds it themselves (FR-23; the in-app report endpoint lands in Phase 2). |
