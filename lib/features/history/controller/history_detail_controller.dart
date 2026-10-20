import 'dart:io';

import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../services/storage/local_store.dart';

/// One saved clean, full-screen: compare before/after (if original exists),
/// share it, or delete it (photo + entry, permanent).
class HistoryDetailController extends GetxController {
  HistoryDetailController({
    required this.localStore,
    Future<void> Function(List<XFile> files)? shareFiles,
  }) : _shareFiles = shareFiles ?? Share.shareXFiles;

  final LocalStore localStore;
  final Future<void> Function(List<XFile> files) _shareFiles;

  late final HistoryEntry entry;

  final compareMode = false.obs;
  final showOriginal = false.obs;

  bool get hasOriginal {
    final orig = entry.originalPath;
    return orig != null && File(orig).existsSync();
  }

  void toggleCompare() {
    compareMode.value = !compareMode.value;
  }

  @override
  void onInit() {
    super.onInit();
    entry = Get.arguments as HistoryEntry;
  }

  final isSaving = false.obs;
  final saved = false.obs;

  Future<void> saveToGallery() async {
    if (isSaving.value || saved.value) return;
    isSaving.value = true;
    final stopwatch = Stopwatch()..start();
    final result = await localStore.saveToGallery(entry.localPath);
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 400) {
      await Future<void>.delayed(Duration(milliseconds: 400 - elapsed));
    }
    switch (result) {
      case Success<void>():
        saved.value = true;
        AppHaptics.success();
        AppSnackbar.success(AppStrings.resultSavedSnackbar);
      case Failure<void>(:final failure):
        AppHaptics.error();
        AppSnackbar.error(failure.userMessageKey);
    }
    isSaving.value = false;
  }

  Future<void> share() async {
    await _shareFiles(<XFile>[XFile(entry.localPath)]);
  }

  Future<void> delete() async {
    final confirmed = await AppDialog.confirm(
      titleKey: AppStrings.historyDeleteTitle,
      bodyKey: AppStrings.historyDeleteBody,
      confirmLabelKey: AppStrings.commonDelete,
      cancelLabelKey: AppStrings.commonCancel,
      destructive: true,
    );
    if (!confirmed) return;
    final result = await localStore.deleteHistory(entry.id);
    switch (result) {
      case Success<void>():
        Get.back<String>(result: entry.id);
        AppSnackbar.success(AppStrings.historyDeletedSnackbar);
      case Failure<void>(:final failure):
        AppSnackbar.error(failure.userMessageKey);
    }
  }
}
