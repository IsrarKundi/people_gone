import 'package:get/get.dart';

import '../controller/result_controller.dart';

/// Result feature binding — the ONLY place [ResultController] is
/// registered (Conventions §7 rule 2).
class ResultBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ResultController>(() => ResultController());
  }
}
