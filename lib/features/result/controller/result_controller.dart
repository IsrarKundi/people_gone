import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../services/storage/local_store.dart';
import '../../processing/model/processing_args.dart';
import '../widgets/keeper_sheet.dart';

/// Result (S7): judge the clean at full quality, then Save / Share /
/// fix. Saving — and only saving — consumes a free save (FR-16);
/// previews and re-runs are always free (FR-11).
class ResultController extends GetxController {
  ResultController({
    required this.localStore,
    required this.config,
    Future<void> Function(List<XFile> files)? shareFiles,
    Future<bool> Function(Uri uri)? openLink,
  }) : _shareFiles = shareFiles ?? Share.shareXFiles,
       _openLink = openLink ?? launchUrl;

  final LocalStore localStore;
  final AppConfig config;
  final Future<void> Function(List<XFile> files) _shareFiles;
  final Future<bool> Function(Uri uri) _openLink;

  /// Free saves per month on the free tier (§9.1).
  static const int freeSavesPerMonth = 10;

  late final ProcessingOutcome outcome;

  final savesLeft = freeSavesPerMonth.obs;
  final saved = false.obs;
  final isSaving = false.obs;
  final compareMode = false.obs;
  final showOriginal = false.obs;

  @override
  void onInit() {
    super.onInit();
    outcome = Get.arguments as ProcessingOutcome;
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
  bool get canCorrectKeeper => totalCount >= 2 && !nobodyRemoved;

  /// Every detected person id with its kept/removed state, for the
  /// keeper-correction sheet.
  List<({int id, bool kept})> get people {
    final kept = outcome.keeperIds.toSet();
    final all = <int>{...outcome.keeperIds, ...outcome.removedIds}.toList()
      ..sort();
    return all.map((id) => (id: id, kept: kept.contains(id))).toList();
  }

  /// Save (FR-14/FR-16): gallery first, then history, then — only on
  /// full success — one free save is consumed.
  Future<void> save() async {
    if (saved.value || isSaving.value || nobodyRemoved) return;
    if (savesLeft.value <= 0) {
      await AppDialog.info(
        titleKey: AppStrings.savesOutTitle,
        bodyKey: AppStrings.savesOutBody,
      );
      return;
    }
    isSaving.value = true;
    final gallery = await localStore.saveToGallery(outcome.resultPath);
    if (gallery case Failure<void>(:final failure)) {
      isSaving.value = false;
      AppSnackbar.error(failure.userMessageKey);
      return;
    }
    final id = 'save_${DateTime.now().microsecondsSinceEpoch}';
    final adopted = await localStore.adoptIntoHistory(outcome.resultPath, id);
    if (adopted case Success<String>(:final value)) {
      await localStore.addHistory(
        HistoryEntry(id: id, localPath: value, savedAt: DateTime.now()),
      );
      await localStore.consumeFreeSave();
      savesLeft.value = savesLeft.value - 1;
      saved.value = true;
      AppSnackbar.success(AppStrings.resultSavedSnackbar);
    } else {
      AppSnackbar.error(AppStrings.errorSaveFailed);
    }
    isSaving.value = false;
  }

  /// Share the result file through the system sheet (FR-17). No
  /// watermark is ever added, free or paid.
  Future<void> share() async {
    await _shareFiles(<XFile>[XFile(outcome.resultPath)]);
  }

  /// Report this result (FR-23): opens the user's mail app to the
  /// support address from config with job counts only — the photo is
  /// attached only if the user adds it themselves. The in-app report
  /// endpoint replaces this when the gateway lands (Phase 2).
  Future<void> report() async {
    final subject = Uri.encodeComponent('PeopleGone result report');
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
    AppSheet.show(KeeperSheet(people: people, onChoose: chooseKeeper));
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
