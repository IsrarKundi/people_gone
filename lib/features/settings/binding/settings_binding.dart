import 'package:get/get.dart';

import '../../../config/app_config.dart';
import '../../../services/storage/local_store.dart';
import '../controller/settings_controller.dart';

/// Settings feature binding — the ONLY place [SettingsController] is
/// registered (Conventions §7 rule 2).
class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SettingsController>(
      () => SettingsController(
        localStore: Get.find<LocalStore>(),
        config: Get.find<AppConfig>(),
      ),
    );
  }
}
