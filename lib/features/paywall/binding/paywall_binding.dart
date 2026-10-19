import 'package:get/get.dart';

import '../../../services/purchase/purchase_service.dart';
import '../controller/paywall_controller.dart';

/// Paywall feature binding. Controllers are registered here — and only here.
class PaywallBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PaywallController>(
      () => PaywallController(
        purchaseService: Get.isRegistered<PurchaseService>()
            ? Get.find<PurchaseService>()
            : null,
      ),
    );
  }
}
