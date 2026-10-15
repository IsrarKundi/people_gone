import 'package:get/get.dart';

import '../controller/splash_controller.dart';

/// Registers [SplashController] when the splash route is opened.
class SplashBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SplashController>(() => SplashController());
  }
}
