import 'package:get/get.dart';

import '../controller/home_controller.dart';

/// Home feature binding — the ONLY place [HomeController] is registered
/// (Conventions §7 rule 2).
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
  }
}
