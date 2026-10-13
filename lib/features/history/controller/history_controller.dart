import 'package:get/get.dart';

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
    await Get.toNamed<void>(Routes.historyDetail, arguments: entry);
    await load();
  }
}
