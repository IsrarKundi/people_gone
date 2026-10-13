import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/widgets/primary_button.dart';
import 'package:people_gone/core/widgets/secondary_button.dart';
import 'package:people_gone/features/processing/model/processing_args.dart';

import '../processing/processing_flow_test.dart' show pngBytes;
import 'result_flow_test.dart' show FakeProcessingApi, TestBinding, TrackingStore;

/// Review 04 F7: at large text scales the Save/Share row must stack
/// (Save full-width, Share full-width beneath) instead of squeezing
/// Share until its label breaks mid-word. At ordinary scales and
/// widths the approved 75/25 row stands.
void main() {
  late Directory tempDir;
  late File original;
  late File resultFile;
  late TrackingStore store;
  late FakeProcessingApi api;

  const config = AppConfig(
    apiBaseUrl: 'https://worker.test',
    providerDisplayName: "PeopleGone's processing servers",
    consentVersion: 1,
    supportEmail: 'support@example.com',
    privacyPolicyUrl: 'https://example.invalid/privacy',
    useGateway: false,
    supabaseUrl: '',
    supabaseAnonKey: '',
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_result_layout');
    original = File('${tempDir.path}/original.png')..writeAsBytesSync(pngBytes);
    resultFile = File('${tempDir.path}/result.png')..writeAsBytesSync(pngBytes);
    store = TrackingStore();
    api = FakeProcessingApi();
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpResultAt(
    WidgetTester tester, {
    required double width,
    required double textScale,
  }) async {
    tester.view.physicalSize = Size(width * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        initialBinding: TestBinding(store, api, config),
        initialRoute: Routes.home,
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(
            name: Routes.home,
            page: () => const Scaffold(body: Text('HOME')),
          ),
          ...AppPages.pages.where((p) => p.name != Routes.home),
        ],
      ),
    );
    await tester.pump();
    Get.offNamed<void>(
      Routes.result,
      arguments: ProcessingOutcome(
        originalPath: original.path,
        resultPath: resultFile.path,
        personsDetected: 2,
        keeperIds: const <int>[0],
        removedIds: const <int>[1],
        totalSeconds: 4.2,
        engineUsed: 'mat',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('F7: at 1.30 text scale on a phone width, Share stacks '
      'full-width below Save and its label stays on one line', (
    tester,
  ) async {
    await pumpResultAt(tester, width: 390, textScale: 1.3);
    expect(tester.takeException(), isNull);

    final saveRect = tester.getRect(find.byType(PrimaryButton).first);
    final shareRect = tester.getRect(
      find.ancestor(
        of: find.text('Share'),
        matching: find.byType(SecondaryButton),
      ),
    );
    // Stacked: Share begins at or below Save's bottom edge, and both
    // buttons span the same full width.
    expect(shareRect.top, greaterThanOrEqualTo(saveRect.bottom - 1));
    expect((shareRect.width - saveRect.width).abs(), lessThan(1.0));
    // The word itself never breaks: one rendered line.
    final shareTextSize = tester.getSize(find.text('Share'));
    expect(shareTextSize.height, lessThan(36));
  });

  testWidgets('F7 control: at 1.0 on a wide surface the 75/25 row '
      'stands side by side', (tester) async {
    await pumpResultAt(tester, width: 800, textScale: 1.0);
    expect(tester.takeException(), isNull);

    final saveRect = tester.getRect(find.byType(PrimaryButton).first);
    final shareRect = tester.getRect(
      find.ancestor(
        of: find.text('Share'),
        matching: find.byType(SecondaryButton),
      ),
    );
    // Same row: vertical centres align (the buttons have different
    // token heights, 52 vs 48, so tops differ by design).
    expect(
      (shareRect.center.dy - saveRect.center.dy).abs(),
      lessThan(1.0),
    );
    expect(shareRect.left, greaterThan(saveRect.left));
    expect(shareRect.width, lessThan(saveRect.width));
  });
}
