import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/consent_sheet.dart';
import '../../../services/storage/local_store.dart';

/// Settings: only rows that tell the truth today (Design Direction §4
/// S-Settings) — the free-saves balance, who processes photos (from
/// config), how photos are handled (the consent copy, re-readable), and
/// the privacy policy link. No dead rows, no dark patterns (FR-31).
class SettingsController extends GetxController {
  SettingsController({
    required this.localStore,
    required this.config,
    Future<bool> Function(Uri uri)? openLink,
  }) : _openLink = openLink ?? launchUrl;

  final LocalStore localStore;
  final AppConfig config;
  final Future<bool> Function(Uri uri) _openLink;

  static const int freeSavesPerMonth = 10;

  final savesLeft = freeSavesPerMonth.obs;

  /// When the free-saves counter resets (from LocalStore's counter
  /// period — never a date invented in the UI; Review 02 A6).
  final resetDate = Rxn<DateTime>();

  String get providerName => config.providerDisplayName;

  @override
  void onInit() {
    super.onInit();
    localStore.freeSavesUsed().then((result) {
      if (result case Success<int>(:final value)) {
        savesLeft.value = (freeSavesPerMonth - value).clamp(
          0,
          freeSavesPerMonth,
        );
      }
    });
    localStore.freeSavesResetDate().then((result) {
      if (result case Success<DateTime>(:final value)) {
        resetDate.value = value;
      }
    });
  }

  void openPrivacyPolicy() => _openLink(Uri.parse(config.privacyPolicyUrl));

  /// Diagnostics (2026-10-14): the shareable step log for failures.
  void openDiagnostics() => Get.toNamed<void>(Routes.diagnostics);

  /// "How your photos are handled" re-opens the exact consent wording,
  /// read-only: a single "Close" action, no Cancel (Review 02 F5/A4).
  void showPhotoHandling() {
    AppSheet.show(
      ConsentSheet(
        titleKey: AppStrings.consentTitle,
        bodyKey: AppStrings.consentBody,
        bodyParams: <String, String>{'provider': config.providerDisplayName},
        variant: ConsentSheetVariant.readOnly,
        continueLabelKey: AppStrings.commonClose,
        footerKey: AppStrings.consentPrivacyLink,
        onFooterTap: openPrivacyPolicy,
        onContinue: () => Get.back<void>(),
      ),
    );
  }
}
