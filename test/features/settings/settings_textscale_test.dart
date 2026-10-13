import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/features/settings/controller/settings_controller.dart';
import 'package:people_gone/features/settings/view/settings_view.dart';

import 'settings_view_test.dart' show FakeStore;

/// Review 04 F8 proof: at the maximum text scale (1.30) the provider
/// row's label still renders in full — never squeezed into a letter
/// column by the long provider value beside it.
void main() {
  tearDown(Get.reset);

  testWidgets('provider label renders fully at text scale 1.30', (
    tester,
  ) async {
    Get.put<SettingsController>(
      SettingsController(
        localStore: FakeStore(),
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
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        home: const SettingsView(),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(textScaler: const TextScaler.linear(1.30)),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The full label is one rendered text, with no overflow exception.
    expect(find.text('Processing provider'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final label = tester.getRect(find.text('Processing provider'));
    final value = tester.getRect(find.text("PeopleGone's processing servers"));
    // One full line wide (a letter column would be a few px), and the
    // value lives beneath it.
    expect(label.width, greaterThan(150));
    expect(value.top, greaterThanOrEqualTo(label.bottom));
    expect(find.text('Processing & Privacy'), findsOneWidget);
  });
}
