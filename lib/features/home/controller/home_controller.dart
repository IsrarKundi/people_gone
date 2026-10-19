import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/consent_sheet.dart';
import '../../../services/processing/job_tracker.dart';
import '../../../services/storage/local_store.dart';
import '../../picker/controller/picker_controller.dart';
import '../../proposal/model/proposal_args.dart';


/// Home (S1): the saves indicator, the one primary action (Pick a
/// photo), and the recent-history section. Picking runs the consent
/// gate first (first run only, §4.2) and then hands the photo to
/// Proposal (S4), whose analysing state detects people before any
/// removal is confirmed (Review 04 F1). The on-device save counter is a display hint — the
/// server ledger is the production truth (§7.2).
class HomeController extends GetxController {
  HomeController({
    required this.localStore,
    required this.picker,
    required this.config,
    Future<bool> Function(Uri uri)? openLink,
  }) : _openLink = openLink ?? launchUrl;

  final LocalStore localStore;
  final PickerController picker;
  final AppConfig config;
  final Future<bool> Function(Uri uri) _openLink;

  static const int freeSavesPerMonth = 10;

  final savesLeft = freeSavesPerMonth.obs;
  final resetDate = Rxn<DateTime>();
  final history = <HistoryEntry>[].obs;
  final errorMessage = RxnString();

  bool get isPicking => picker.isPicking.value;
  bool get hasHistory => history.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    reloadData();
  }

  /// Reloads the counter, reset date, and history. Storage failures degrade to the
  /// defaults — Home never blocks on its own bookkeeping.
  Future<void> reloadData() async {
    final used = await localStore.freeSavesUsed();
    if (used case Success<int>(:final value)) {
      savesLeft.value = (freeSavesPerMonth - value).clamp(0, freeSavesPerMonth);
    }
    final reset = await localStore.freeSavesResetDate();
    if (reset case Success<DateTime>(:final value)) {
      resetDate.value = value;
    }
    final entries = await localStore.history();
    if (entries case Success<List<HistoryEntry>>(:final value)) {
      history.assignAll(value);
    }
    final jobResult = await localStore.gatewayJob();
    if (jobResult case Success<GatewayJobRecord?>(:final value)) {
      if (value != null && value.stage == 'processing') {
        if (JobTracker.instance.activeJob.value == null) {
          JobTracker.instance.trackStarted(photoPath: value.photoPath);
        }
      }
    }
  }


  Future<void> onPickPhoto() async {
    errorMessage.value = null;
    final picked = await picker.pickPhoto();
    switch (picked) {
      case Failure<String?>(:final failure):
        errorMessage.value = failure.userMessageKey;
      case Success<String?>(:final value):
        if (value == null) return; // user backed out of the picker
        if (!await _consentAccepted()) {
          _showConsent(value);
          return;
        }
        await _openProposal(value);
    }
  }

  Future<bool> _consentAccepted() async {
    final stored = await localStore.acceptedConsentVersion();
    if (stored case Success<int?>(:final value)) {
      return value != null && value >= config.consentVersion;
    }
    return false;
  }

  /// First-run consent (S2): the only thing between the first pick and
  /// processing — one sheet, decided once (§4.2, §11.2A).
  void _showConsent(String photoPath) {
    AppSheet.show(
      ConsentSheet(
        titleKey: AppStrings.consentTitle,
        bodyKey: AppStrings.consentBody,
        bodyParams: <String, String>{'provider': config.providerDisplayName},
        continueLabelKey: AppStrings.consentContinue,
        footerKey: AppStrings.consentPrivacyLink,
        onFooterTap: () => _openLink(Uri.parse(config.privacyPolicyUrl)),
        onContinue: () async {
          await localStore.setAcceptedConsentVersion(config.consentVersion);
          Get.back<void>();
          await _openProposal(photoPath);
        },
        onCancel: () => Get.back<void>(),
      ),
    );
  }

  /// Golden path (Review 04 F1): pick → consent → Proposal. The
  /// proposal screen runs detection itself and only routes onward to
  /// Processing once the user confirms who is removed.
  Future<void> _openProposal(String photoPath) async {
    await Get.toNamed<void>(
      Routes.proposal,
      arguments: ProposalArgs.forPhoto(photoPath: photoPath),
    );
    await reloadData();
  }

  Future<void> openHistory() async {
    await Get.toNamed<void>(Routes.history);
    await reloadData();
  }

  /// Tapping a Home history tile opens THAT photo's detail (same
  /// behaviour as the History screen's grid) — not the list.
  Future<void> openHistoryDetail(HistoryEntry entry) async {
    await Get.toNamed<void>(Routes.historyDetail, arguments: entry);
    await reloadData();
  }

  void openSettings() => Get.toNamed<void>(Routes.settings);

  void openPaywall() {
    if (savesLeft.value == 0) {
      Get.toNamed<void>(Routes.paywall);
    }
  }
}
