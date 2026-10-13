import 'package:get/get.dart';

import '../../../services/processing/processing_api.dart';
import '../../../services/storage/local_store.dart';
import '../controller/processing_controller.dart';

/// Processing feature binding — the ONLY place [ProcessingController] is
/// registered (Conventions §7 rule 2).
class ProcessingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProcessingController>(
      () => ProcessingController(
        processingApi: Get.find<ProcessingApi>(),
        localStore: Get.find<LocalStore>(),
      ),
    );
  }
}
