import 'package:get/get.dart';

import '../controller/picker_controller.dart';

/// Picker feature binding — the ONLY place [PickerController] is
/// registered (Conventions §7 rule 2). Composed into the Home route by
/// the wiring layer (app_pages), since picking starts from Home's one
/// primary action.
class PickerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PickerController>(() => PickerController());
  }
}
