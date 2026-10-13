import 'package:get/get.dart';

import '../../../config/app_config.dart';
import '../../../services/storage/local_store.dart';
import '../../picker/controller/picker_controller.dart';
import '../controller/home_controller.dart';

/// Home feature binding — the ONLY place [HomeController] is registered
/// (Conventions §7 rule 2). The Home route composes this with
/// PickerBinding first (see app_pages): the controller takes its
/// PickerController from that registration.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(
      () => HomeController(
        localStore: Get.find<LocalStore>(),
        picker: Get.find<PickerController>(),
        config: Get.find<AppConfig>(),
      ),
    );
  }
}
