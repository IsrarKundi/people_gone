# AGENTS.md — PeopleGone

Standing rules for any AI coding agent working in this repo. **Read this file first, every session.**

## Read before writing any code
1. `PEOPLEGONE_REQUIREMENTS.md` — the only product truth. Read §1–§3 before any code; read the section you are implementing before each task (§14 lists tasks in order; each task cites its sections).
2. `FOLDER_STRUCTURE_AND_CONVENTIONS.md` — binding rules for file placement, naming, GetX patterns, and the design system.

Authority order: `PEOPLEGONE_REQUIREMENTS.md` → `FOLDER_STRUCTURE_AND_CONVENTIONS.md` → this file. If they conflict, the higher one wins and the conflict is reported, never silently resolved.

## Toolchain
- Flutter version (FVM pin, `.fvmrc`): **3.47.7** (stable channel, Dart 3.13.5) — pinned in `.fvmrc` in Build Task 1.1; keep in sync with CI.
- Every requirement with an ID (`FR-xx`, `NFR-xx`, `CMP-xx`) is testable. A task is done only when its acceptance criteria (Requirements §13) pass.
- Never invent a decision the requirements already make. If something is genuinely unspecified, choose the option that is (a) simpler, (b) cheaper to run, (c) more private — in that order — and record it in `docs/architecture/` as an ADR.

## NEVER
- Add a media/library permission. Photo access is system-picker only.
- Commit any secret, key, keystore, or `.env` (real values). Never put an AI-vendor or server secret in the mobile app.
- Call an AI/GPU vendor from the client. The app calls `ProcessingApi` → our gateway only.
- Log, store in analytics, or send to any third party the content of a user's photo. Never log image data or image URLs.
- Hard-code prices or the processing-provider name (prices come from the store via `PurchaseService`; provider name comes from config).
- Use "Magic Eraser" or "Magic Editor" anywhere — app name, store metadata, in-app copy, marketing. Never market watermark or logo removal, anywhere, ever.
- Silently downscale a user's photo. Output dimensions always equal input dimensions.

## ALWAYS
- Cite the requirements section you implement in the commit/PR. Commit format: `<phase>-<task>: <summary> (FR-xx, §n)`.
- Run `flutter analyze` (must be clean) + `flutter test` (must pass) before declaring any task done.
- Update `docs/compliance/store-forms.md` in the same change if data behaviour changes.
- Keep every hand-written file under ~400 lines.
- Stop at human-only steps (store accounts, legal agreements, entering secrets, package/bundle ID decision, pressing Submit) and leave them as a checklist for the developer instead of guessing.

## Secrets & config
- Client config is non-secret only — API base URL, provider display name, `consent_version`, support email, privacy URL — via `--dart-define-from-file`; prod config injected by CI.
- `.gitignore` must cover `.env*` (except `.env.example`), `**/key.properties`, `**/*.jks`, `**/*.keystore`, `server/.env`.

## Structure & conventions (from FOLDER_STRUCTURE_AND_CONVENTIONS.md — binding)
- Follow FOLDER_STRUCTURE_AND_CONVENTIONS.md exactly. Its "Where does this go?" table (§2) decides placement of every new file; if a case is missing, choose the closest analogue and note it in the PR.
- Features live in lib/features/<name>/ with binding/ controller/ model/ view/ widgets/. Controllers are registered ONLY in bindings; NEVER Get.put inside build(). Views are dumb: layout + Obx only.
- Services are interfaces in lib/services/<area>/; implementations are the ONLY files that import dio, purchases_flutter, flutter_secure_storage, or path_provider. The app never calls an AI/GPU vendor — only ProcessingApi → our gateway.
- Design tokens ONLY: colours from core/constants/app_colors.dart (light+dark), text styles from app_text.dart, sizes from app_sizes.dart. No raw Color(...), no raw font sizes, no magic padding/radius numbers in feature code. All UI strings via core/strings/app_strings.dart keys.
- Fonts are bundled assets (Inter / NotoSansArabic / NotoNastaliqUrdu). google_fonts is forbidden.
- Errors: services return Result<T>; controllers expose error state as string keys; views render ErrorView/AppSnackbar. No try/catch in views, no ad-hoc Get.snackbar/Get.dialog in features.
- Max ~400 lines per file. flutter analyze clean + flutter test passing before any task is called done. Commit format: <phase>-<task>: <summary> (FR-xx, §n).
