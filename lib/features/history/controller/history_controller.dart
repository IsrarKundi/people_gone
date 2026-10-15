import 'package:get/get.dart';

import '../../../core/constants/app_motion.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/result.dart';
import '../../../services/storage/local_store.dart';

/// History (S1 section / own screen): every clean the user saved, kept
/// only on this device (FR-19). Deleting happens on the detail screen;
/// this list reloads on return.
class HistoryController extends GetxController {
  HistoryController({required this.localStore});

  final LocalStore localStore;
  final entries = <HistoryEntry>[].obs;
  final deletingId = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final result = await localStore.history();
    if (result case Success<List<HistoryEntry>>(:final value)) {
      entries.assignAll(value);
    }
  }

  Future<void> openDetail(HistoryEntry entry) async {
    final deletedId =
        await Get.toNamed<String>(Routes.historyDetail, arguments: entry);
    if (deletedId != null) {
      deletingId.value = deletedId;
      await Future<void>.delayed(AppMotion.deleteScale);
      entries.removeWhere((e) => e.id == deletedId);
      deletingId.value = null;
    }
    await load();
  }
}
