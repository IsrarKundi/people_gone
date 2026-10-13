import 'package:get/get.dart';

import '../../../config/app_config.dart';
import '../../../services/storage/local_store.dart';
import '../controller/result_controller.dart';

/// Result feature binding — the ONLY place [ResultController] is
/// registered (Conventions §7 rule 2).
class ResultBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ResultController>(
      () => ResultController(
        localStore: Get.find<LocalStore>(),
        config: Get.find<AppConfig>(),
      ),
    );
  }
}
