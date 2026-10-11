# PeopleGone — Folder Structure & Conventions

**Status:** Normative. This file is the permanent structure rulebook for the PeopleGone repo.
**Authority order:** `PEOPLEGONE_REQUIREMENTS.md` (product truth) → this file (code organisation truth) → `AGENTS.md` (session rules for the coding agent). If this file and the requirements conflict, the requirements win and this file must be amended.
**Origin:** Conventions adapted from the developer's Darzi project (github.com/IsrarKundi/darzi, analysed 2026-10-12 at HEAD `674fd92`), reconciled against PeopleGone Requirements §6. Where Darzi and PeopleGone conflicted, PeopleGone won; every such decision is recorded in §2 of the architect's Step 2 table and in §11 of this file.

---

## 1. Full folder tree (annotated)

### 1.1 Repo level

```
peoplegone/
├── AGENTS.md                       # Standing rules for the AI coding agent. Read first, every session. Content per Requirements §6.3 + §12 of this file.
├── README.md                       # What the app is, how to run it, where the spec lives. No product decisions here.
├── PEOPLEGONE_REQUIREMENTS.md      # THE product spec. Only normative product document.
├── FOLDER_STRUCTURE_AND_CONVENTIONS.md   # This file.
├── .fvmrc                          # FVM pin: one exact Flutter version. Committed. Never hand-edit casually.
├── .gitignore                      # Per Requirements §6.3 (env files, keystores, keys). 
├── .env.example                    # Non-secret client config TEMPLATE only (keys, no real values).
├── docs/
│   ├── compliance/                 # privacy-policy.md, store-forms.md, consent-copy.md, record-of-processing.md (Requirements §11)
│   ├── architecture/               # ADRs: one file per decision, NNN-short-title.md. Phase 0 decision note lives here.
│   ├── licences/                   # Archived model-weight licences (Requirements §3.1).
│   └── release/                    # play-submission-checklist.md, appstore-submission-checklist.md
├── app/                            # The Flutter application (this file's §1.2 covers app/lib).
│   ├── pubspec.yaml
│   ├── pubspec.lock                # Committed. Never hand-edited.
│   ├── analysis_options.yaml       # flutter_lints + strict casts/inference (Requirements §6.1).
│   ├── assets/                     # See §6.4 for asset rules.
│   │   ├── fonts/                  # Bundled font files ONLY (no runtime downloads).
│   │   ├── images/
│   │   ├── icons/
│   │   └── animations/
│   ├── lib/                        # See §1.2.
│   ├── test/                       # Mirrors lib/ structure (see §5).
│   ├── integration_test/
│   ├── android/                    # Manifest must contain NO media/library permissions. Ever.
│   └── ios/                        # Deployment target 15.0; PrivacyInfo.xcprivacy present (Phase 2).
├── server/                         # Supabase config, Edge Functions, DB migrations.
│   └── worker/                     # GPU worker container (Python) — host-agnostic (Requirements §6.4/§7).
└── .github/workflows/              # ci.yml: flutter analyze + flutter test on PR; release build on tag.
```

### 1.2 app/lib level

```
lib/
├── main.dart                       # Minimal entry ONLY: WidgetsFlutterBinding, config load, InitialBinding services, runApp. No UI, no feature logic.
├── config/
│   └── app_config.dart             # AppConfig: reads --dart-define-from-file JSON. Non-secret values ONLY: apiBaseUrl, providerDisplayName, consentVersion, supportEmail, privacyPolicyUrl. Prices NEVER live here (they come from the store via PurchaseService); disclosure TEXT templates may reference config values.
├── core/
│   ├── bindings/
│   │   └── initial_binding.dart    # Registers global services (interfaces → implementations), permanent. The ONLY place global Get.put lives.
│   ├── constants/
│   │   ├── app_colors.dart         # AppPalette (ThemeExtension): light + dark semantic token sets. The ONLY file with Color(0x...) literals.
│   │   ├── app_text.dart           # AppTextStyles: the full type scale as functions of the palette. The ONLY file with font sizes/weights.
│   │   └── app_sizes.dart          # AppSizes: spacing, radii, heights, icon sizes, breakpoints, durations. The ONLY file with layout magic numbers.
│   ├── routes/
│   │   ├── app_routes.dart         # Route name constants (class Routes). No widgets here.
│   │   └── app_pages.dart          # List<GetPage>: route → view + binding. The ONLY place routes are wired.
│   ├── strings/
│   │   └── app_strings.dart        # Every user-visible string as a key constant + GetX Translations map (en today; ur added later without touching views).
│   ├── theme/
│   │   ├── app_theme.dart          # AppTheme.light() / AppTheme.dark() built ONLY from tokens. ThemeMode.system is set in main/GetMaterialApp.
│   │   └── theme_ext.dart          # BuildContext extensions: context.palette, context.textStyles, context.sizes shortcuts.
│   ├── utils/
│   │   ├── formatters.dart         # Pure functions only (dates, counts) via intl. No widgets, no state.
│   │   └── result.dart             # Result<T> / AppFailure types used by services → controllers (see §8.4).
│   └── widgets/                    # The shared widget kit (§7). Feature-agnostic only.
│       ├── app_scaffold.dart
│       ├── primary_button.dart
│       ├── secondary_button.dart
│       ├── loading_overlay.dart
│       ├── error_view.dart
│       ├── empty_view.dart
│       ├── app_dialog.dart
│       ├── app_snackbar.dart       # The ONLY snackbar helper. Views/controllers call this, never Get.snackbar directly.
│       ├── consent_sheet.dart      # Shell only; wording comes from strings/config (Requirements §11.2).
│       └── section_header.dart
├── features/
│   └── <feature_name>/             # picker, processing, result, history, paywall, settings (Requirements §6.2). Template in §4.
│       ├── binding/
│       ├── controller/
│       ├── model/
│       ├── view/
│       └── widgets/                # Widgets used ONLY by this feature.
└── services/                       # The ONLY code allowed to touch network, billing, or storage (Requirements §6).
    ├── processing/
    │   ├── processing_api.dart         # ABSTRACT interface only in this folder's root file.
    │   └── processing_api_impl.dart    # dio implementation. The only file that knows the API base URL and endpoints.
    ├── purchase/
    │   ├── purchase_service.dart       # ABSTRACT interface (entitlement stream, offerings with STORE prices, purchase, restore).
    │   └── purchase_service_impl.dart  # RevenueCat (purchases_flutter) implementation. The only file importing purchases_flutter.
    ├── storage/
    │   ├── local_store.dart            # ABSTRACT interface (history files + index, consent record, tokens).
    │   └── local_store_impl.dart       # path_provider + flutter_secure_storage implementation.
    └── connectivity/
        └── connectivity_service.dart   # connectivity_plus wrapper exposing an Rx<bool>/Stream<bool>.
```

---

## 2. "Where does this go?" decision table

| You are adding… | It goes in… | Rule |
|---|---|---|
| A new screen | `features/<feature>/view/<name>_view.dart` + route in `core/routes/` | One view file per screen. View = layout + Obx only. |
| A new controller | `features/<feature>/controller/<name>_controller.dart` | Registered in that feature's binding. Never `Get.put` in a view. |
| A feature binding | `features/<feature>/binding/<feature>_binding.dart` | Wired in `core/routes/app_pages.dart` on the feature's first route. |
| A widget used by 2+ features | `core/widgets/` | Must be feature-agnostic (no feature imports). |
| A widget used by 1 feature | `features/<feature>/widgets/` | Never promoted "just in case". Promote when a second feature needs it. |
| A new API call | `services/<area>/` interface + impl | Features/controllers NEVER import dio or call URLs. |
| A new model (DTO/entity) | `features/<feature>/model/` if one feature uses it; `core/` has NO models folder — a truly shared model goes in the owning feature and is imported from there, or an ADR promotes it to `core/models/` | Models are immutable, `fromJson`/`toJson`, no logic beyond derived getters. |
| A new constant (layout/colour/text) | `core/constants/` token files ONLY | See §6. No literals in features. |
| A new user-visible string | `core/strings/app_strings.dart` | Key constant + en entry. Views use `'key'.tr` via the key constant. |
| A new colour | `app_colors.dart`, in BOTH light and dark palettes | Semantic name (what it means), never a hue name for UI roles. |
| A new asset | `app/assets/<type>/` + declared in `pubspec.yaml` | Naming per §5. Fonts additionally registered in pubspec `fonts:` section. |
| A price | NOWHERE in code | Prices come from the store through `PurchaseService` offerings at runtime. |
| A provider name / disclosure text | `config/app_config.dart` (name) / `core/strings` (text, may interpolate config) | Per AGENTS.md: never hard-code provider name in UI. |
| A new global service | `services/<area>/` + registered in `core/bindings/initial_binding.dart` | Interface first. |
| A test | `app/test/` mirroring the lib path | See §9. |

---

## 3. Naming conventions

| Thing | Convention | Example |
|---|---|---|
| Files | `snake_case` + role suffix | `home_view.dart`, `home_controller.dart`, `home_binding.dart` |
| Views | `<Name>View` (StatelessWidget or GetView) | `ProposalView` |
| Controllers | `<Name>Controller extends GetxController` | `ProcessingController` |
| Bindings | `<Feature>Binding extends Bindings` | `ProcessingBinding` |
| Services (interface) | `<Area>Service` / `ProcessingApi` (per Requirements §6.1 naming) | `PurchaseService`, `ProcessingApi` |
| Service implementations | Interface name + `Impl` | `PurchaseServiceImpl` |
| Models | Plain noun, immutable | `PersonInstance`, `JobResult` |
| Routes | `Routes.<name>` constants, path in kebab-case | `Routes.proposal = '/proposal'` |
| String keys | `snake_case`, grouped by screen prefix | `home_pick_photo`, `proposal_remove_n` |
| Assets | `snake_case`, type prefix | `img_empty_history.png`, `ic_shield.svg`, `anim_processing.json` |
| Fonts (family names in pubspec) | `Inter`, `NotoSansArabic`, `NotoNastaliqUrdu` | — |
| Tests | Mirror lib file + `_test.dart` | `test/features/history/controller/history_controller_test.dart` |
| Enums | `PascalCase` type, `camelCase` values | `JobStatus.queued` |
| Rx variables | plain name + type suffix in declaration only (`RxInt`, `RxBool`, `RxList<T>`, `.obs`) | `final savesLeft = 10.obs;` |

---

## 4. Feature template (every feature folder MUST contain exactly this shape)

```
features/<feature>/
├── binding/<feature>_binding.dart
├── controller/<feature>_controller.dart
├── model/                      # may be empty only if the feature truly has no model — delete the folder then, don't leave placeholders
├── view/<screen>_view.dart     # one file per screen of this feature
└── widgets/                    # feature-only widgets; delete if none
```

### 4.1 Binding skeleton

```dart
import 'package:get/get.dart';
import '../controller/example_controller.dart';

class ExampleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ExampleController>(() => ExampleController(
          processingApi: Get.find<ProcessingApi>(),
          localStore: Get.find<LocalStore>(),
        ));
  }
}
```

### 4.2 Controller skeleton

```dart
import 'package:get/get.dart';
import '../../../core/utils/result.dart';
import '../../../services/processing/processing_api.dart';
import '../../../services/storage/local_store.dart';

class ExampleController extends GetxController {
  ExampleController({required this.processingApi, required this.localStore});

  final ProcessingApi processingApi;
  final LocalStore localStore;

  final isLoading = false.obs;
  final errorMessage = RxnString();

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    final result = await processingApi.fetchSomething();
    isLoading.value = false;
    switch (result) {
      case Success(:final value):
        // update state
      case Failure(:final failure):
        errorMessage.value = failure.userMessageKey; // a string KEY, resolved in the view
    }
  }
}
```

### 4.3 View skeleton

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../controller/example_controller.dart';

class ExampleView extends GetView<ExampleController> {
  const ExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return AppScaffold(
      titleKey: 'example_title',
      body: Obx(() {
        if (controller.isLoading.value) return const LoadingOverlay();
        if (controller.errorMessage.value != null) {
          return ErrorView(messageKey: controller.errorMessage.value!, onRetry: controller.load);
        }
        return ListView(padding: EdgeInsets.all(s.screenPadding), children: const []);
      }),
    );
  }
}
```

Rules visible in the skeletons: constructor injection of service **interfaces**; views contain **zero** business logic; loading/error are first-class states in every view; the view reads design tokens via `context.palette` / `context.sizes`, never via `Color(...)` or raw numbers.

---

## 5. Naming of tests & test placement

- Unit tests for controllers/services/utils: `app/test/` mirroring `lib/`.
- Widget tests for the shared kit: `app/test/core/widgets/`.
- Integration test for the golden path: `app/integration_test/golden_path_test.dart` (Requirements §13/§14 Task 1.3 uses the mock server).
- Every controller ships with at least one test covering its success and failure paths (§9).

---

## 6. Design system — the consistency layer

**One source of truth:** `lib/core/constants/` (tokens) + `lib/core/theme/` (ThemeData built from tokens). Feature code NEVER contains a raw `Color(...)`, a raw font size, or a magic padding/radius number. Violations fail review (see §10 right/wrong examples).

### 6.1 Colours — semantic palette (values live ONLY in `app_colors.dart` as an `AppPalette` ThemeExtension)

Brand direction (decided, NOT Darzi's identity): a calm **trust blue** primary with a **teal** secondary — clean, photographic, credible for a utility that handles private photos. Neutrals are slightly cool. Saturated colours are semantic only.

| Token | Light | Dark | Used for |
|---|---|---|---|
| `primary` | `#3157D5` | `#8FA8FF` | Primary actions, active states |
| `onPrimary` | `#FFFFFF` | `#0B1026` | Text/icons on primary |
| `primaryContainer` | `#E3E9FD` | `#26335F` | Selected chips, subtle highlights |
| `secondary` | `#0E7C86` | `#4FD1C5`-family `#45B8C4` | Secondary accents, links |
| `background` | `#F7F8FA` | `#0E1013` | Scaffold background |
| `surface` | `#FFFFFF` | `#17191E` | Cards, sheets |
| `surfaceVariant` | `#EEF0F4` | `#1F2229` | Inset areas, skeletons |
| `textPrimary` | `#16181D` | `#F2F3F5` | Headings, body |
| `textSecondary` | `#5A6068` | `#A7ADB8` | Supporting text |
| `textTertiary` | `#8A919C` | `#6E757F` | Captions, hints |
| `border` | `#DFE3E9` | `#2A2E36` | Hairlines, card borders |
| `success` / `successBg` | `#1E7D46` / `#E2F4E8` | `#4CC38A` / `#123527` | Success states |
| `warning` / `warningBg` | `#9A6A00` / `#FBF0D3` | `#F5C15C` | Warnings (e.g. overlap risk note, Requirements §4 S4) |
| `error` / `errorBg` | `#C0362C` / `#FBE7E4` | `#FF8A80` / `#3A1D1A` | Errors |
| `scrim` | `#0A0C10` @ 55% | `#000000` @ 60% | Modal overlays |
| `overlayRemoved` | `#E5484D` @ 55% fill, solid stroke | `#FF6369` @ 55% fill, solid stroke | Person proposed for REMOVAL on S4 Proposal (Requirements §4) |
| `overlayKept` | `#30A46C` @ 55% fill, solid stroke | `#3DD68C` @ 55% fill, solid stroke | Protected subject(s) on S4 Proposal |

Dark mode: `ThemeMode.system` — the app follows the OS setting (Requirements §11/§6 decision). There is NO in-app theme toggle in v1.

### 6.2 Typography — bundled fonts ONLY

**Families (bundled as assets in `assets/fonts/`, registered in `pubspec.yaml`; the `google_fonts` package is FORBIDDEN — no runtime downloads):**

| Family | Role | Justification |
|---|---|---|
| `Inter` (static weights 400/600/700/800) | All Latin UI text | Clean, neutral, highly legible at small sizes, excellent numerals — the trustworthy-utility look. OFL licence. |
| `NotoSansArabic` (400/600/700) | Urdu (and Arabic-script) body text, future localisation | Same Noto design family discipline as Darzi proved; covers Urdu characters Inter lacks. OFL. |
| `NotoNastaliqUrdu` (400/700) | Urdu headings only, future localisation | Nastaliq is the expected Urdu display script (Darzi lesson); never for body, digits, or buttons. OFL. |

**Type scale (values live ONLY in `app_text.dart`; `sp`, logical):**

| Style | Size | Weight | Line height | Notes |
|---|---|---|---|---|
| `display` | 32 | 700 | 1.20 | Rare: paywall hero, onboarding |
| `headlineLg` | 24 | 700 | 1.25 | Screen heroes |
| `headlineMd` | 20 | 600 | 1.30 | Section heroes |
| `titleLg` | 18 | 600 | 1.35 | App-bar titles, card titles |
| `titleMd` | 16 | 600 | 1.40 | List titles, button-adjacent titles |
| `bodyLg` | 16 | 400 | 1.50 | Primary reading text |
| `bodyMd` | 14 | 400 | 1.50 | Default body |
| `bodySm` | 13 | 400 | 1.45 | Secondary body (minimum body size) |
| `labelLg` | 14 | 600 | 1.40 | Buttons |
| `labelMd` | 12 | 600 | 1.35 | Chips, badges |
| `caption` | 12 | 400 | 1.40 | Hints, disclosure lines |
| `overline` | 11 | 600 | 1.30, letter-spacing 0.8 | Eyebrow labels |

Urdu adjustments (when `ur` locale is active): body styles switch family to `NotoSansArabic` at the SAME sizes (never below 13sp); headings switch to `NotoNastaliqUrdu` with line height **2.0**; digits/amounts always render in the Latin/NotoSansArabic run, LTR (Darzi rule, carried over). Text styles are functions of the active palette — a style never hard-codes a colour outside the palette.

### 6.3 Spacing, radius, sizes, motion (values live ONLY in `app_sizes.dart`)

| Group | Tokens |
|---|---|
| Spacing scale (4-base) | `xxs 2, xs 4, sm 8, md 12, lg 16, xl 20, xxl 24, xxxl 32, huge 40, giant 48` |
| Screen padding | `screenPadding 16` (compact), `20` at medium breakpoint and up |
| Card padding | `cardPadding 16` |
| Radius | `radiusSm 8, radiusMd 12, radiusLg 16, radiusXl 20, radiusSheet 28 (top corners), pill 999` |
| Control heights | `buttonPrimary 52, buttonSecondary 48, buttonCompact 40, input 52, listRowMin 56, appBar 56` |
| Icon sizes | `iconSm 20, iconMd 24, iconLg 28` |
| Touch targets | minimum **48×48** everywhere (Darzi rule, carried over) |
| Elevation/shadow | Flat by default: surfaces separated by `border` hairlines, elevation 0. Shadows ONLY for floating elements: `shadowSheet` = blur 24, offset (0, 8), colour `scrim` @ 18%; `shadowDialog` = blur 16, offset (0, 4), `scrim` @ 15% |
| Breakpoints (Material window classes) | `compact < 600`, `medium 600–839`, `expanded ≥ 840` |
| Max content width | `contentMaxWidth 640` — on medium/expanded, content is centred and capped; this is a phone-first utility, not a tablet app |
| Animation | `fast 120ms, normal 200ms, slow 320ms`; curves: `easeOutCubic` default, `easeInOut` for sheet/modal |

### 6.4 Responsive / sizing rule (ONE approach, decided)

**Fixed logical-pixel tokens + breakpoint layout changes. `flutter_screenutil` and any percentage-of-screen sizing are FORBIDDEN.**

- Flutter logical pixels are already density-independent; Darzi's fixed-dp discipline worked and keeps the AI agent's output predictable.
- Sizes do NOT scale with screen width. What changes at breakpoints is *layout*: e.g. History grid columns 3 (compact) → 4 (medium) → 5 (expanded, within the 640 cap).
- Text scales ONLY with the user's system text setting, clamped: `textScaler` clamped to **0.85–1.30** in the app builder so accessibility scaling works without breaking layouts.
- All spacing in feature code references `AppSizes` tokens — a size that is not in the scale does not exist.

### 6.5 Strings

- ALL user-visible text lives in `core/strings/app_strings.dart`: a key constant + the GetX `Translations` map. Views write `AppStrings.homePickPhoto.tr` — never a literal, never a bare key string typed inline.
- English (`en_US`) ships in v1. Urdu (`ur_PK`) entries are added in the same file when localisation lands; NO view changes are needed when it does.
- **Exceptions by rule, not by convenience:** prices come from the store (`PurchaseService`), the processing-provider name comes from `AppConfig.providerDisplayName`, and store-disclosure/consent texts live in strings but are versioned by `AppConfig.consentVersion` (Requirements §11).

### 6.6 Assets

| Folder | Contents | Rules |
|---|---|---|
| `assets/fonts/` | Inter, NotoSansArabic, NotoNastaliqUrdu font files | Registered in pubspec. No other font source exists. |
| `assets/images/` | Raster illustrations/empty-state art | `img_<name>.png`, provide @2x/@3x where shipped |
| `assets/icons/` | Custom icons not in Material set | `ic_<name>.svg` preferred; Material icons are the default — custom only when Material lacks the glyph |
| `assets/animations/` | Lottie/Rive for processing/empty states | `anim_<name>.json`; must have a static fallback |

### 6.7 Shared widget kit (in `core/widgets/` — every screen MUST build from these)

| Widget | Purpose |
|---|---|
| `AppScaffold` | Scaffold + SafeArea + optional app bar; the only scaffold features use |
| `PrimaryButton` / `SecondaryButton` | Token heights/styles; built-in loading state (spinner replaces label, disabled) |
| `LoadingOverlay` | Full-screen and inline progress (indeterminate + determinate variants) |
| `ErrorView` | Icon + message (by string key) + Retry button |
| `EmptyView` | Illustration/icon + line of text + optional action (Darzi's PlaceholderView, generalised) |
| `AppDialog` | The only dialog shell (confirm/info); token radius, scrim, button order |
| `AppSnackbar` | The only snackbar path (success/info/error variants) |
| `ConsentSheet` | Modal sheet shell for S2-style consent/disclosure (Requirements §4/§11) |
| `SectionHeader` | Title + optional trailing action |
| `AppCard` | The only card container (surface + border + radiusLg) |

---

## 7. GetX rules

1. **Controllers** extend `GetxController`. State is `Rx`/`RxList`/`Rxn` fields + derived getters. No `setState` in views; `StatefulWidget` only when a framework API forces it (document why in a comment).
2. **Bindings own registration.** Feature controllers are registered ONLY in their feature binding (`Get.lazyPut` with constructor injection). Global services are registered ONLY in `InitialBinding` (`Get.put<X>(Impl(), permanent: true)`).
3. **FORBIDDEN (Darzi habits, explicitly banned here):** `Get.put` inside a `build()` method; registering the same controller twice; `Get.find` in widgets for anything except the controller (views use `GetView<T>` / `controller` getter); navigating with `Navigator.push` — routes go through `Get.toNamed(Routes.x)` / `Get.offNamed` / `Get.back`.
4. **Routes:** every screen is a `GetPage` in `core/routes/app_pages.dart` with its binding. Route names only from `core/routes/app_routes.dart`.
5. **Services are injected as interfaces** via controller constructors (see §4.2). Controllers never import an `*_impl.dart`.
6. **Errors reach the UI as state, not exceptions:** services return `Result<T>` (`core/utils/result.dart`); controllers convert `Failure` into `errorMessage` (a string KEY) + state; views render `ErrorView` or `AppSnackbar`. No `try/catch` in views. No raw exception text shown to users.
7. **Snackbars/dialogs** are triggered by controllers through one-shot state or by views calling `core/widgets` helpers — never `Get.snackbar`/`Get.dialog` called ad hoc in feature code (Darzi called `Get.snackbar` directly in controllers; standardised here so copy and styling stay consistent).
8. **Lifecycle:** controllers release resources in `onClose` (subscriptions, controllers, streams). Long-lived streams (entitlement, connectivity) are subscribed in `onInit`, cancelled in `onClose`.

---

## 8. Dependency rules (who may import whom)

```
view  →  controller (same feature), core/*, services INTERFACES (types only, via controller — views should not import services at all in practice)
controller → services interfaces, own feature's model/, core/utils, core/strings, core/routes
services impl → dio / purchases_flutter / flutter_secure_storage / path_provider (each SDK in exactly ONE impl file)
features → NEVER import another feature's internals. Cross-feature navigation uses Routes; cross-feature data goes through a service or an ADR-created shared model.
core → imports NOTHING from features/ or services/ (core is the foundation; the arrow never points up).
main.dart → config, core/bindings, core/routes, core/theme, core/strings only.
```

- **Network, billing, storage SDKs appear ONLY inside `services/*_impl.dart`.** A `dio`, `purchases_flutter`, or `flutter_secure_storage` import anywhere else is a review-blocking defect.
- The mobile app NEVER calls an AI/GPU vendor directly (Requirements AGENTS rule) — it calls `ProcessingApi`, which talks to OUR gateway only.

---

## 9. Quality rules

| Rule | Standard |
|---|---|
| File length | **~400 lines max** for any hand-written Dart file (Requirements §6.2). Extract a widget/part; never grow past it. |
| Lints | `flutter_lints` + `strict-casts`, `strict-inference`, `strict-raw-types` in `analysis_options.yaml`. `flutter analyze` must be clean — zero warnings — before a task is done. |
| Formatting | `dart format` defaults; CI checks. |
| Tests | Every controller: success + failure path tests. Every shared widget: at least one widget test. Golden-path integration test against the mock (Phase 1, Task 1.3). |
| Hard-coded values | Zero raw colours/font sizes/layout numbers outside `core/constants/`. Zero literal UI strings outside `core/strings/`. |
| Permissions | `AndroidManifest.xml` must contain NO media/library permission. Photo access is system-picker only (Requirements §11). A permission appearing in the manifest fails the task. |
| Secrets | No secret, key, keystore, or `.env` (real values) in the repo, ever (Requirements §6.3). Client config is non-secret `--dart-define-from-file` only. |
| Commits / PRs | Message/PR format: `<phase>-<task>: <summary> (FR-xx, §n)` — cite the Requirements section and requirement IDs implemented. One task per PR where practical. |

---

## 10. Right vs wrong (design-system usage)

```dart
// ✅ RIGHT — tokens, strings, kit widgets
Container(
  padding: EdgeInsets.all(context.sizes.lg),
  decoration: BoxDecoration(
    color: context.palette.surface,
    borderRadius: BorderRadius.circular(context.sizes.radiusLg),
    border: Border.all(color: context.palette.border),
  ),
  child: Text(AppStrings.homePickPhoto.tr, style: context.textStyles.titleMd),
)

// ❌ WRONG — raw colour, raw radius, raw padding, literal string, ad-hoc style
Container(
  padding: const EdgeInsets.all(17),
  decoration: BoxDecoration(
    color: const Color(0xFFFFFFFF),
    borderRadius: BorderRadius.circular(15),
  ),
  child: const Text('Pick a photo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
)
```

```dart
// ✅ RIGHT — controller gets the interface, returns state; view stays dumb
final result = await processingApi.analyse(jobId);
// ❌ WRONG — view (or controller) touching dio / URLs / RevenueCat directly
final resp = await Dio().post('https://api.example.com/analyse', data: ...);
```

---

## 11. Definition of done (any task)

- [ ] Implements exactly the cited Requirements section(s) / FR IDs — nothing extra, nothing missing.
- [ ] `flutter analyze` clean; `dart format` applied.
- [ ] `flutter test` passes, including new tests for new logic (§9).
- [ ] No file over ~400 lines; no raw colours/sizes/strings outside their token/string files.
- [ ] Works in light AND dark (system) themes; checked both.
- [ ] No new permission in `AndroidManifest.xml`; no secret in the repo; no SDK import outside its service impl.
- [ ] Commit/PR message cites section + FR IDs (§9).
- [ ] Anything human-only (accounts, signing, secrets, store submission) is listed as a checklist for the developer, NOT guessed or faked.

---

## 12. Paste this block into AGENTS.md (in addition to Requirements §6.3)

```markdown
## Structure & conventions (from FOLDER_STRUCTURE_AND_CONVENTIONS.md — binding)
- Follow FOLDER_STRUCTURE_AND_CONVENTIONS.md exactly. Its "Where does this go?" table (§2) decides placement of every new file; if a case is missing, choose the closest analogue and note it in the PR.
- Features live in lib/features/<name>/ with binding/ controller/ model/ view/ widgets/. Controllers are registered ONLY in bindings; NEVER Get.put inside build(). Views are dumb: layout + Obx only.
- Services are interfaces in lib/services/<area>/; implementations are the ONLY files that import dio, purchases_flutter, flutter_secure_storage, or path_provider. The app never calls an AI/GPU vendor — only ProcessingApi → our gateway.
- Design tokens ONLY: colours from core/constants/app_colors.dart (light+dark), text styles from app_text.dart, sizes from app_sizes.dart. No raw Color(...), no raw font sizes, no magic padding/radius numbers in feature code. All UI strings via core/strings/app_strings.dart keys.
- Fonts are bundled assets (Inter / NotoSansArabic / NotoNastaliqUrdu). google_fonts is forbidden.
- Errors: services return Result<T>; controllers expose error state as string keys; views render ErrorView/AppSnackbar. No try/catch in views, no ad-hoc Get.snackbar/Get.dialog in features.
- Max ~400 lines per file. flutter analyze clean + flutter test passing before any task is called done. Commit format: <phase>-<task>: <summary> (FR-xx, §n).
```

---

## 13. Decisions inherited from Darzi (kept) vs rejected (banned) — summary

**Kept from Darzi (proven in the developer's own project):** GetX everywhere with `.obs` state and dumb `StatelessWidget`/`GetView` screens; single-source constants for colours/text/sizes with a written ban on literals; all strings through GetX i18n keys; `intl`-only number/date formatting (pure `core/utils/formatters.dart`); models with `fromJson`/`toJson` from day one; seed/sample data in controllers, never in widgets; minimum 48dp touch targets; a written rules file living in the repo; one primary CTA per screen.

**Banned (Darzi habits PeopleGone must not repeat):** `google_fonts` runtime downloads (fonts are bundled assets here); `Get.put` inside `build()`; direct `Get.snackbar` calls scattered in controllers (one `AppSnackbar` helper instead); a single light theme (PeopleGone ships light + dark, system-following); token arithmetic in widgets (`AppSizes.gapXxl + 8` style — a value not in the scale does not exist); theme code hard-coding text styles outside the text-style file; placeholder screens with dead buttons (PeopleGone placeholders are design-token demos with no fake actions); zero tests (tests are part of done here).
