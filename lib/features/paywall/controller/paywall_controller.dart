import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../services/purchase/purchase_service.dart';
import '../model/paywall_args.dart';

/// Controller for S8 Paywall.
/// Fetches offerings from [PurchaseService] when available.
/// Prices come ONLY from [PurchaseService] — never hardcoded (AGENTS.md).
/// When [PurchaseService] returns nothing or fails, price slots remain empty.
class PaywallController extends GetxController {
  PaywallController({
    this.purchaseService,
    PaywallArgs? args,
  }) : args = args ?? (Get.arguments is PaywallArgs ? Get.arguments as PaywallArgs : const PaywallArgs());

  final PurchaseService? purchaseService;
  final PaywallArgs args;

  /// Selected plan id ('yearly', 'lifetime', 'monthly').
  /// Annual/Yearly is pre-selected per Requirements §9.3 & Design Direction §S8.
  final selectedPlan = 'yearly'.obs;

  final offerings = <String, StoreOffering>{}.obs;
  final isLoadingOfferings = false.obs;
  final loadError = false.obs;

  bool get hasPhoto => args.hasPhoto;
  String? get photoPath => args.resultPath;
  String? get originalPath => args.originalPath;
  String? get arrivalReason => args.arrivalReason;

  @override
  void onInit() {
    super.onInit();
    loadOfferings();
  }

  Future<void> loadOfferings() async {
    final service = purchaseService ?? (Get.isRegistered<PurchaseService>() ? Get.find<PurchaseService>() : null);
    if (service == null) {
      // Stub-safe: no service registered yet. Price slots render empty.
      return;
    }

    isLoadingOfferings.value = true;
    loadError.value = false;

    final result = await service.offerings();
    isLoadingOfferings.value = false;

    switch (result) {
      case Success<List<StoreOffering>>(:final value):
        final map = <String, StoreOffering>{};
        for (final item in value) {
          map[item.period.toLowerCase()] = item;
        }
        offerings.value = map;
      case Failure<List<StoreOffering>>():
        loadError.value = true;
    }
  }

  void selectPlan(String plan) {
    selectedPlan.value = plan;
  }

  /// Price string from the store for [period] ('yearly', 'lifetime', 'monthly').
  /// Returns empty string if not supplied by the store (never typed/hardcoded prices).
  String priceFor(String period) {
    final offering = offerings[period.toLowerCase()];
    return offering?.priceString ?? '';
  }

  void close() => Get.back<void>();

  Future<void> restore() async {
    final service = purchaseService ?? (Get.isRegistered<PurchaseService>() ? Get.find<PurchaseService>() : null);
    if (service == null) {
      AppSnackbar.info(AppStrings.paywallPurchaseUnavailable);
      return;
    }
    final result = await service.restore();
    switch (result) {
      case Success<bool>(value: final isPro):
        if (isPro) {
          Get.back<bool>(result: true);
        } else {
          AppSnackbar.info(AppStrings.paywallPurchaseUnavailable);
        }
      case Failure<bool>(:final failure):
        AppSnackbar.error(failure.userMessageKey);
    }
  }

  void onContinue() {
    // RevenueCat purchase calls are OUT of scope — no store accounts exist yet.
    // The CTA is disabled-with-note per ANTIGRAVITY-HANDOFF.md.
    AppSnackbar.info(AppStrings.paywallPurchaseUnavailable);
  }
}
