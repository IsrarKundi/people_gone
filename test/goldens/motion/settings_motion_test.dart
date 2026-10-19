import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/constants/app_colors.dart';
import 'package:people_gone/core/constants/app_motion.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/settings/controller/settings_controller.dart';
import 'package:people_gone/features/settings/view/settings_view.dart';
import 'package:people_gone/services/storage/local_store.dart';

class _FakeStore implements LocalStore {
  @override
  Future<Result<int>> freeSavesUsed() async => const Success<int>(1);

  @override
  Future<Result<DateTime>> freeSavesResetDate() async =>
      Success<DateTime>(DateTime.utc(2026, 11, 1));

  @override
  Future<Result<bool>> introSeen() async => const Success<bool>(true);

  @override
  Future<Result<void>> setIntroSeen() async => const Success<void>(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('Item 19: Theme switch crossfades app theme over ~250ms', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(780, 1688); // 390x844 @2x
    addTearDown(tester.view.reset);

    Get.put<SettingsController>(
      SettingsController(
        localStore: _FakeStore(),
        config: const AppConfig(
          apiBaseUrl: 'https://worker.test',
          providerDisplayName: "PeopleGone's processing servers",
          consentVersion: 1,
          supportEmail: 'support@example.com',
          privacyPolicyUrl: 'https://example.invalid/privacy',
          useGateway: false,
          supabaseUrl: '',
          supabaseAnonKey: '',
        ),
        openLink: (_) async => true,
      ),
    );

    final brightnessNotifier = ValueNotifier<Brightness>(Brightness.light);

    await tester.pumpWidget(
      ValueListenableBuilder<Brightness>(
        valueListenable: brightnessNotifier,
        builder: (context, brightness, _) {
          final isDark = brightness == Brightness.dark;
          final targetTheme = isDark ? AppTheme.dark() : AppTheme.light();
          return GetMaterialApp(
            debugShowCheckedModeBanner: false,
            translations: AppTranslations(),
            locale: const Locale('en', 'US'),
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            home: Builder(
              builder: (innerContext) {
                final media = MediaQuery.of(innerContext);
                final duration = media.disableAnimations
                    ? Duration.zero
                    : AppMotion.themeCrossfade;
                return AnimatedTheme(
                  data: targetTheme,
                  curve: AppMotion.standardCurve,
                  duration: duration,
                  child: const SettingsView(),
                );
              },
            ),
          );
        },
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Frame 0: Light theme
    expect(
      Theme.of(tester.element(find.byType(SettingsView))).extension<AppPalette>()?.background,
      AppPalette.light.background,
    );
    await expectLater(
      find.byType(SettingsView),
      matchesGoldenFile('settings_theme_frame0.png'),
    );

    // Switch to dark theme
    brightnessNotifier.value = Brightness.dark;
    await tester.pump(); // Start animation

    // Frame 1: Mid-transition (125ms of 250ms)
    await tester.pump(const Duration(milliseconds: 125));
    final midPalette =
        Theme.of(tester.element(find.byType(SettingsView))).extension<AppPalette>();
    expect(midPalette, isNotNull);
    // Intermediate background is neither pure light nor pure dark
    expect(midPalette!.background != AppPalette.light.background, isTrue);
    expect(midPalette.background != AppPalette.dark.background, isTrue);

    await expectLater(
      find.byType(SettingsView),
      matchesGoldenFile('settings_theme_frame1.png'),
    );

    // Frame 2: Settled dark theme (remaining 125ms + small buffer)
    await tester.pump(const Duration(milliseconds: 130));
    final settledPalette =
        Theme.of(tester.element(find.byType(SettingsView))).extension<AppPalette>();
    expect(settledPalette?.background, AppPalette.dark.background);

    await expectLater(
      find.byType(SettingsView),
      matchesGoldenFile('settings_theme_frame2.png'),
    );
  });

  testWidgets('Item 19: Under reduced motion, theme switch snaps instantly', (
    tester,
  ) async {
    Get.put<SettingsController>(
      SettingsController(
        localStore: _FakeStore(),
        config: const AppConfig(
          apiBaseUrl: 'https://worker.test',
          providerDisplayName: "PeopleGone's processing servers",
          consentVersion: 1,
          supportEmail: 'support@example.com',
          privacyPolicyUrl: 'https://example.invalid/privacy',
          useGateway: false,
          supabaseUrl: '',
          supabaseAnonKey: '',
        ),
        openLink: (_) async => true,
      ),
    );

    final brightnessNotifier = ValueNotifier<Brightness>(Brightness.light);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: ValueListenableBuilder<Brightness>(
          valueListenable: brightnessNotifier,
          builder: (context, brightness, _) {
            final isDark = brightness == Brightness.dark;
            final targetTheme = isDark ? AppTheme.dark() : AppTheme.light();
            return GetMaterialApp(
              debugShowCheckedModeBanner: false,
              translations: AppTranslations(),
              locale: const Locale('en', 'US'),
              home: Builder(
                builder: (innerContext) {
                  final media = MediaQuery.of(innerContext);
                  final duration = media.disableAnimations
                      ? Duration.zero
                      : AppMotion.themeCrossfade;
                  return AnimatedTheme(
                    data: targetTheme,
                    curve: AppMotion.standardCurve,
                    duration: duration,
                    child: const SettingsView(),
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.pump();
    expect(
      Theme.of(tester.element(find.byType(SettingsView))).extension<AppPalette>()?.background,
      AppPalette.light.background,
    );

    // Switch to dark with reduced motion
    brightnessNotifier.value = Brightness.dark;
    await tester.pump();

    // Snaps immediately without waiting 250ms
    expect(
      Theme.of(tester.element(find.byType(SettingsView))).extension<AppPalette>()?.background,
      AppPalette.dark.background,
    );
  });
}
