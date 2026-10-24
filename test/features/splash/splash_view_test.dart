import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
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

    // Verify key brand elements are present (Lottie logo animation & Artivo footer)
    expect(find.byType(LottieBuilder), findsOneWidget);
    final lottie = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
    expect((lottie.lottie as AssetLottie).assetName, SplashView.lottieLight);
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

  testWidgets('SplashView renders dark theme Lottie animation in dark mode', (tester) async {
    final controller = SplashController(
      holdDuration: const Duration(seconds: 5),
    );
    Get.put<SplashController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData.dark(),
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        home: const SplashView(),
      ),
    );

    await tester.pump();

    expect(find.byType(LottieBuilder), findsOneWidget);
    final lottie = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
    expect((lottie.lottie as AssetLottie).assetName, SplashView.lottieDark);

    controller.complete();
    await tester.pump();
  });

  testWidgets('SplashView completes when the logo animation finishes, not on the hold timer', (tester) async {
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

    // The 500ms hold timer is cancelled once the logo animation starts,
    // so completion must NOT happen at 600ms...
    await tester.pump(const Duration(milliseconds: 600));
    expect(completed, isFalse);

    // ...but must happen once the ~1670ms logo animation finishes.
    await tester.pump(const Duration(milliseconds: 1400));
    expect(completed, isTrue);
  });

  testWidgets('SplashController falls back to the hold timer when no view plays the animation', (tester) async {
    var completed = false;
    final controller = SplashController(
      onComplete: () => completed = true,
    );
    Get.put<SplashController>(controller);

    // No SplashView pumped, so nothing cancels the timer: the default
    // 1400ms hold must still complete on its own.
    await tester.pumpWidget(
      const GetMaterialApp(
        home: SizedBox.shrink(),
      ),
    );

    await tester.pump();
    expect(completed, isFalse);

    // After 1.2s, should still be holding (since hold is 1400ms)
    await tester.pump(const Duration(milliseconds: 1200));
    expect(completed, isFalse);

    // After remaining 250ms (total > 1400ms), should auto-complete
    await tester.pump(const Duration(milliseconds: 250));
    expect(completed, isTrue);
  });
}
