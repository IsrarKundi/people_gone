import 'dart:async';

import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';


import '../../../config/app_config.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../services/processing/processing_api.dart';
import '../../../services/storage/local_store.dart';
import '../../brush/model/brush_args.dart';
import '../../paywall/model/paywall_args.dart';
import '../../processing/model/processing_args.dart';
import '../widgets/keeper_sheet.dart';

/// Result (S7): judge the clean at full quality, then Save / Share /
/// fix. Saving — and only saving — consumes a free save (FR-16);
/// previews and re-runs are always free (FR-11).
class ResultController extends GetxController {
  ResultController({
    required this.localStore,
    required this.config,
    this.processingApi,
    Future<void> Function(List<XFile> files)? shareFiles,
    Future<bool> Function(Uri uri)? openLink,
  }) : _shareFiles = shareFiles ?? Share.shareXFiles,
       _openLink = openLink ?? launchUrl;

  final LocalStore localStore;
  final AppConfig config;

  /// The gateway API for the save-credit gate (§7.3); null in direct
  /// mode builds/tests that never gate a save.
  final ProcessingApi? processingApi;
  final Future<void> Function(List<XFile> files) _shareFiles;
  final Future<bool> Function(Uri uri) _openLink;

  /// Free saves per month on the free tier (§9.1).
  static const int freeSavesPerMonth = 10;

  late final ProcessingOutcome outcome;

  /// The CURRENT result file: a brush touch-up replaces it (FR-09),
  /// and save/share/history all use this path, never a stale one.
  late final RxString resultPath;

  String? _saveKey;

  final savesLeft = freeSavesPerMonth.obs;
  final saved = false.obs;
  final isSaving = false.obs;
  final compareMode = false.obs;
  final showOriginal = false.obs;

  @override
  void onInit() {
    super.onInit();
    outcome = Get.arguments as ProcessingOutcome;
    resultPath = outcome.resultPath.obs;
    unawaitedRefresh();
  }

  // onInit must stay synchronous; the counter load runs unawaited.
  void unawaitedRefresh() {
    localStore.freeSavesUsed().then((result) {
      if (result case Success<int>(:final value)) {
        savesLeft.value = (freeSavesPerMonth - value).clamp(
          0,
          freeSavesPerMonth,
        );
      }
    });
  }

  bool get nobodyRemoved => outcome.nobodyRemoved;
  int get removedCount => outcome.removedIds.length;
  int get totalCount => outcome.personsDetected;

  /// User-included ambiguous belongings removed by this job (v3).
  /// Attached belongings are part of their person and are never
  /// itemised in the summary (design X16).
  int get itemsRemoved => outcome.itemsRemoved;

  /// Distractions removed by this job (v3, Phase B).
  int get distractionsRemoved => outcome.distractionsRemoved;

  /// The S7 summary line (design X16): extends only when the job
  /// actually included group items; belongings that travelled with a
  /// person are never itemised. A distractions-only extension names
  /// them ("…and 2 distractions removed"); a job that mixed
  /// belongings and distractions counts them together as items —
  /// the sentence stays exact, the group was one list on S4.
  String get summaryLine {
    final params = <String, String>{
      'removed': '$removedCount',
      'total': '$totalCount',
    };
    if (distractionsRemoved > 0 && itemsRemoved == 0) {
      return (distractionsRemoved == 1
              ? AppStrings.resultSummaryDistractionOne
              : AppStrings.resultSummaryDistractions)
          .trParams(<String, String>{
            ...params,
            'distractions': '$distractionsRemoved',
          });
    }
    final extras = itemsRemoved + distractionsRemoved;
    if (extras > 0) {
      return (extras == 1
              ? AppStrings.resultSummaryItemOne
              : AppStrings.resultSummaryItems)
          .trParams(<String, String>{...params, 'items': '$extras'});
    }
    return AppStrings.resultSummary.trParams(params);
  }

  bool get canCorrectKeeper => totalCount >= 2 && !nobodyRemoved;

  /// Every detected person id with its kept/removed state, for the
  /// keeper-correction sheet.
  List<({int id, bool kept})> get people {
    final kept = outcome.keeperIds.toSet();
    final all = <int>{...outcome.keeperIds, ...outcome.removedIds}.toList()
      ..sort();
    return all.map((id) => (id: id, kept: kept.contains(id))).toList();
  }

  bool get _gatewayMode => config.useGateway && processingApi != null;

  Future<void> _refundGatewayCredit() async {
    if (_gatewayMode && _saveKey != null) {
      await processingApi!.refundSaveCredit(idempotencyKey: _saveKey!);
    }
  }

  /// Save (FR-14/FR-16): gallery first, then history, then — only on
  /// full success — one free save is consumed. In gateway mode the
  /// server ledger gates the save first (§7.3): no credit, no save;
  /// a local failure after the credit was consumed refunds it (§7.2).
  Future<void> save() async {
    if (saved.value || isSaving.value || nobodyRemoved) return;
    int? gatewaySavesLeft;
    if (_gatewayMode) {
      isSaving.value = true;
      _saveKey ??= 'save_${resultPath.value.hashCode}';
      final decisionResult = await processingApi!.consumeSaveCredit(
        idempotencyKey: _saveKey!,
      );
      switch (decisionResult) {
        case Failure<SaveCreditDecision>(:final failure):
          isSaving.value = false;
          AppSnackbar.error(failure.userMessageKey);
          return;
        case Success<SaveCreditDecision>(:final value):
          if (value.savesLeft != null) {
            savesLeft.value = value.savesLeft!;
            gatewaySavesLeft = value.savesLeft;
          }
          if (value.paymentRequired) {
            isSaving.value = false;
            unawaited(
              Get.toNamed<void>(
                Routes.paywall,
                arguments: PaywallArgs(
                  originalPath: outcome.originalPath,
                  resultPath: resultPath.value,
                  arrivalReason: AppStrings.savesOutBody.tr,
                ),
              ),
            );
            return;
          }
          if (!value.allowed) {
            isSaving.value = false;
            AppSnackbar.error(AppStrings.errorGeneric);
            return;
          }
      }
    } else {
      if (savesLeft.value <= 0) {
        unawaited(
          Get.toNamed<void>(
            Routes.paywall,
            arguments: PaywallArgs(
              originalPath: outcome.originalPath,
              resultPath: resultPath.value,
              arrivalReason: AppStrings.savesOutBody.tr,
            ),
          ),
        );
        return;
      }
      isSaving.value = true;
    }
    final gallery = await localStore.saveToGallery(resultPath.value);
    if (gallery case Failure<void>(:final failure)) {
      await _refundGatewayCredit();
      isSaving.value = false;
      AppSnackbar.error(failure.userMessageKey);
      return;
    }
    final id = 'save_${DateTime.now().microsecondsSinceEpoch}';
    final adopted = await localStore.adoptIntoHistory(resultPath.value, id);
    if (adopted case Success<String>(:final value)) {
      String? adoptedOrig;
      final origResult = await localStore.adoptOriginalIntoHistory(
        outcome.originalPath,
        id,
      );
      if (origResult case Success<String>(value: final origPath)) {
        adoptedOrig = origPath;
      }
      await localStore.addHistory(
        HistoryEntry(
          id: id,
          localPath: value,
          savedAt: DateTime.now(),
          originalPath: adoptedOrig ?? outcome.originalPath,
        ),
      );
      await localStore.consumeFreeSave();
      savesLeft.value = savesLeft.value - 1;
      if (gatewaySavesLeft != null) savesLeft.value = gatewaySavesLeft;
      saved.value = true;
      AppHaptics.success();
      AppSnackbar.success(AppStrings.resultSavedSnackbar);
    } else {

      AppHaptics.error();
      await _refundGatewayCredit();
      AppSnackbar.error(AppStrings.errorSaveFailed);
    }
    isSaving.value = false;
  }

  /// Phase D (X13): the worker flagged a probable reflection of a
  /// removed person. Shown only when somebody was actually removed.
  bool get reflectionWarning =>
      outcome.reflectionWarning && !nobodyRemoved;

  /// The first probable reflection region, handed to Brush as its
  /// starting guide (X14) — the user still paints it themselves.
  List<int>? get reflectionRegion =>
      outcome.reflectionRegions.isNotEmpty
      ? outcome.reflectionRegions.first
      : null;

  /// Brush fix (S5 / FR-09): paints a missed area on the CURRENT
  /// result and re-runs a touch-up. A touch-up never consumes a
  /// credit; the touched result's later Save is a new save cycle.
  Future<void> openTouchUp() async {
    await _openBrush(BrushArgs(imagePath: resultPath.value));
  }

  /// The reflection warning's action (Phase D): the same brush
  /// flow, with the probable reflection region pre-suggested as a
  /// starting outline (X14).
  Future<void> openReflectionFix() async {
    await _openBrush(
      BrushArgs(
        imagePath: resultPath.value,
        suggestedRegion: reflectionRegion,
      ),
    );
  }

  Future<void> _openBrush(BrushArgs args) async {
    // Untyped navigation + cast: every GetPage in AppPages is
    // GetPage<dynamic>, and a typed Get.toNamed<String> cannot cast
    // its route (verified in result_flow_test's touch-up case).
    final raw = await Get.toNamed<dynamic>(Routes.brush, arguments: args);
    final newPath = raw as String?;
    if (newPath != null && newPath != resultPath.value) {
      resultPath.value = newPath;
      saved.value = false;
      _saveKey = null;
    }
  }

  /// Share the result file through the system sheet (FR-17). No
  /// watermark is ever added, free or paid.
  Future<void> share() async {
    await _shareFiles(<XFile>[XFile(resultPath.value)]);
  }

  /// Report this result (FR-23): opens the user's mail app to the
  /// support address from config with job counts only — the photo is
  /// attached only if the user adds it themselves. The in-app report
  /// endpoint replaces this when the gateway lands (Phase 2).
  Future<void> report() async {
    final subject = Uri.encodeComponent('Framora result report');
    final body = Uri.encodeComponent(
      'People detected: ${outcome.personsDetected}\n'
      'People removed: ${outcome.removedIds.length}\n'
      'Processing time: ${outcome.totalSeconds.toStringAsFixed(1)}s\n',
    );
    final uri = Uri.parse(
      'mailto:${config.supportEmail}?subject=$subject&body=$body',
    );
    final opened = await _openLink(uri);
    if (!opened) AppSnackbar.error(AppStrings.errorGeneric);
  }

  /// Keeper correction sheet: every detected person with its state;
  /// choosing a removed person re-runs the clean keeping only them.
  void openKeeperSheet() {
    final boxes = <int, List<int>>{
      for (final p in outcome.persons) p.id: p.box,
    };
    AppSheet.show(
      KeeperSheet(
        people: people,
        onChoose: chooseKeeper,
        imagePath: outcome.originalPath,
        personBoxes: boxes,
      ),
    );
  }

  /// Free re-run with a different keeper (FR-11) — never uses a save.
  void chooseKeeper(int personId) {
    Get.offNamed<void>(
      Routes.processing,
      arguments: ProcessingArgs(
        photoPath: outcome.originalPath,
        keepIds: <int>[personId],
      ),
    );
  }

  void toggleCompare() => compareMode.value = !compareMode.value;

  void goHome() => Get.offAllNamed<void>(Routes.home);

  void pickAnother() => Get.offAllNamed<void>(Routes.home);
}
