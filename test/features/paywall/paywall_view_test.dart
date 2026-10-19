import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/paywall/controller/paywall_controller.dart';
import 'package:people_gone/features/paywall/model/paywall_args.dart';
import 'package:people_gone/features/paywall/view/paywall_view.dart';
import 'package:people_gone/features/paywall/widgets/plan_tile.dart';
import 'package:people_gone/services/purchase/purchase_service.dart';

class FakePurchaseService implements PurchaseService {
  FakePurchaseService({
    this.offeringsList = const <StoreOffering>[],
    this.restoreResult = true,
  });

  final List<StoreOffering> offeringsList;
  final bool restoreResult;
  final StreamController<bool> _isProController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get isPro => _isProController.stream;

  @override
  Future<Result<List<StoreOffering>>> offerings() async =>
      Success<List<StoreOffering>>(offeringsList);

  @override
  Future<Result<bool>> purchase(String offeringId) async =>
      const Success<bool>(true);

  @override
  Future<Result<bool>> restore() async => Success<bool>(restoreResult);
}

void main() {
  Widget createPaywallApp({
    PaywallArgs? args,
    PurchaseService? purchaseService,
  }) {
    return GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      theme: AppTheme.light(),
      initialRoute: Routes.paywall,
      getPages: <GetPage<dynamic>>[
        GetPage<dynamic>(
          name: Routes.paywall,
          page: () => const PaywallView(),
          binding: BindingsBuilder<void>(() {
            Get.lazyPut<PaywallController>(
              () => PaywallController(
                args: args,
                purchaseService: purchaseService,
              ),
            );
          }),
        ),
      ],
    );
  }

  tearDown(() {
    Get.reset();
  });

  group('S8 Paywall View', () {
    testWidgets('renders all 3 plans without hero photo when opened from Home', (
      tester,
    ) async {
      await tester.pumpWidget(createPaywallApp());
      await tester.pump();

      expect(
        find.text(AppStrings.paywallHeadline.tr),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.paywallSubhead.tr),
        findsOneWidget,
      );

      // 3 plans above the fold
      expect(find.byType(PlanTile), findsNWidgets(3));
      expect(find.text('Pro — Yearly'), findsOneWidget);
      expect(find.text('Lifetime'), findsOneWidget);
      expect(find.text('Pro — Monthly'), findsOneWidget);

      // Annual pre-selected as visual anchor
      expect(find.text('Continue — Yearly'), findsOneWidget);
      expect(find.text('Restore Purchases'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);

      // No photo hero elements when opened without photo
      expect(find.text('This photo stays available for 24 hours.'), findsNothing);
    });

    testWidgets('renders hero photo and arrival note when opened from credit-blocked save', (
      tester,
    ) async {
      const args = PaywallArgs(
        resultPath: '/nonexistent/mock_result.jpg',
        originalPath: '/nonexistent/mock_original.jpg',
        arrivalReason: "You've used this month's free saves, so this photo can't be saved yet.",
      );

      await tester.pumpWidget(createPaywallApp(args: args));
      await tester.pump();

      expect(
        find.text("You've used this month's free saves, so this photo can't be saved yet."),
        findsOneWidget,
      );
      expect(find.text('This photo stays available for 24 hours.'), findsOneWidget);
    });

    testWidgets('populates store prices when PurchaseService provides offerings', (
      tester,
    ) async {
      final fakeService = FakePurchaseService(
        offeringsList: const <StoreOffering>[
          StoreOffering(
            id: 'framora_pro_yearly',
            title: 'Yearly',
            priceString: '\$19.99/yr',
            period: 'yearly',
          ),
          StoreOffering(
            id: 'framora_pro_lifetime',
            title: 'Lifetime',
            priceString: '\$49.99',
            period: 'lifetime',
          ),
          StoreOffering(
            id: 'framora_pro_monthly',
            title: 'Monthly',
            priceString: '\$3.99/mo',
            period: 'monthly',
          ),
        ],
      );

      await tester.pumpWidget(createPaywallApp(purchaseService: fakeService));
      await tester.pump();

      expect(find.text('\$19.99/yr'), findsOneWidget);
      expect(find.text('\$49.99'), findsOneWidget);
      expect(find.text('\$3.99/mo'), findsOneWidget);

      // Switching to Lifetime updates the plan and CTA label
      await tester.tap(find.text('Lifetime'));
      await tester.pump();

      expect(find.text('Continue — Lifetime'), findsOneWidget);
    });

    testWidgets('renders empty price slots when PurchaseService returns null/empty (never hardcodes)', (
      tester,
    ) async {
      // No service registered -> stub-safe empty slots
      await tester.pumpWidget(createPaywallApp());
      await tester.pump();

      // No hardcoded prices anywhere
      expect(find.text('\$19.99'), findsNothing);
      expect(find.text('\$49.99'), findsNothing);
      expect(find.text('\$3.99'), findsNothing);
    });
  });
}
