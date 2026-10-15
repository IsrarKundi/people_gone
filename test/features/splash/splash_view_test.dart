import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/features/splash/controller/splash_controller.dart';
import 'package:people_gone/features/splash/view/splash_view.dart';

void main() {
  setUp(() {
    Get.reset();
  });

  testWidgets('SplashView renders brand elements and supports tap skip', (tester) async {
    var completed = false;
    final controller = SplashController(
      holdDuration: const Duration(seconds: 5),
      onComplete: () => completed = true,
    );
    Get.put<SplashController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        home: const SplashView(),
      ),
    );

    // Initial frame
    await tester.pump();

    // Verify key brand elements are present
    expect(find.byType(SvgPicture), findsWidgets);
    expect(find.text('POWERED BY ARTIVO'), findsOneWidget);

    // Advance animation
    await tester.pump(const Duration(milliseconds: 600));

    // Verify punchy tagline appears
    expect(
      find.text('Clear the crowd. Keep your moment.'),
      findsOneWidget,
    );

    // Tap to skip
    await tester.tap(find.byType(SplashView));
    await tester.pump();

    expect(completed, isTrue);
  });

  testWidgets('SplashController auto-completes on timer expiry', (tester) async {
    var completed = false;
    final controller = SplashController(
      holdDuration: const Duration(milliseconds: 500),
      onComplete: () => completed = true,
    );
    Get.put<SplashController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        home: const SplashView(),
      ),
    );

    await tester.pump();
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 600));
    expect(completed, isTrue);
  });
}
