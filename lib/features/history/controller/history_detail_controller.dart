import 'dart:io';

import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

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
        AppSnackbar.success(AppStrings.historyDeletedSnackbar);
        Get.back<String>(result: entry.id);
      case Failure<void>(:final failure):
        AppSnackbar.error(failure.userMessageKey);
    }
  }
}
