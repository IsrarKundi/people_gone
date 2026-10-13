import 'package:get/get.dart';

import '../../../services/storage/local_store.dart';
import '../controller/history_controller.dart';
import '../controller/history_detail_controller.dart';

/// History feature bindings — the ONLY place the history controllers
/// are registered (Conventions §7 rule 2).
class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HistoryController>(
      () => HistoryController(localStore: Get.find<LocalStore>()),
    );
  }
}

/// Detail route binding (registered separately so the list controller
/// and the detail controller never share a route's lifecycle).
class HistoryDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HistoryDetailController>(
      () => HistoryDetailController(localStore: Get.find<LocalStore>()),
    );
  }
}
