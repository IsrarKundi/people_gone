import 'package:get/get.dart';

import '../../../services/processing/processing_api.dart';
import '../../../services/storage/local_store.dart';
import '../controller/brush_controller.dart';

/// Brush feature binding — the ONLY place [BrushController] is
/// registered (Conventions §7 rule 2). Both services are globally
/// registered in InitialBinding.
class BrushBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BrushController>(
      () => BrushController(
        processingApi: Get.find<ProcessingApi>(),
        localStore: Get.find<LocalStore>(),
      ),
    );
  }
}
