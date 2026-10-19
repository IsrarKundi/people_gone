import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/home/controller/home_controller.dart';
import 'package:people_gone/features/home/widgets/interactive_demo_card.dart';
import 'package:people_gone/features/home/widgets/saves_indicator.dart';
import 'package:people_gone/features/picker/controller/picker_controller.dart';
import 'package:people_gone/features/processing/model/processing_args.dart';
import 'package:people_gone/features/result/controller/result_controller.dart';
import 'package:people_gone/services/storage/local_store.dart';

class StubLocalStore implements LocalStore {
  StubLocalStore({this.used = 0});

  int used;

  @override
  Future<Result<int>> freeSavesUsed() async => Success<int>(used);

  @override
  Future<Result<DateTime>> freeSavesResetDate() async =>
      Success<DateTime>(DateTime.utc(2026, 11, 1));

  @override
  Future<Result<void>> consumeFreeSave() async {
    used++;
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryEntry>>> history() async =>
      const Success<List<HistoryEntry>>(<HistoryEntry>[]);

  @override
  Future<Result<void>> addHistory(HistoryEntry entry) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> deleteHistory(String id) async =>
      const Success<void>(null);

  @override
  Future<Result<String>> adoptIntoHistory(String sourcePath, String id) async =>
      Success<String>(sourcePath);

  @override
  Future<Result<String>> adoptOriginalIntoHistory(
    String sourcePath,
    String id,
  ) async =>
      Success<String>(sourcePath);

  @override
  Future<Result<void>> saveToGallery(String localPath) async =>
      const Success<void>(null);

  @override
  Future<Result<int?>> acceptedConsentVersion() async => const Success<int?>(1);

  @override
  Future<Result<void>> setAcceptedConsentVersion(int version) async =>
      const Success<void>(null);

  @override
  Future<Result<String>> writeSessionResult(Uint8List bytes) async =>
      const Success<String>('/mock/session_result.jpg');

  @override
  Future<Result<void>> saveGatewayJob(GatewayJobRecord record) async =>
      const Success<void>(null);

  @override
  Future<Result<GatewayJobRecord?>> gatewayJob() async =>
      const Success<GatewayJobRecord?>(null);

  @override
  Future<Result<void>> clearGatewayJob() async => const Success<void>(null);

  @override
  Future<Result<bool>> introSeen() async => const Success<bool>(true);

  @override
  Future<Result<void>> setIntroSeen() async => const Success<void>(null);
}

void main() {
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

  setUp(() {
    Get.reset();
    InteractiveDemoCard.hasRunTeachingSweep = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('Paywall Entry Points', () {
    testWidgets('Entry Point (a): Home saves line tap when saves = 0 opens paywall', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(780, 1688);
      addTearDown(tester.view.reset);

      final store = StubLocalStore(used: 10); // 0 saves left
      final picker = PickerController();

      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          theme: AppTheme.light(),
          initialRoute: Routes.home,
          getPages: AppPages.pages,
          initialBinding: BindingsBuilder<void>(() {
            Get.put<AppConfig>(config);
            Get.put<LocalStore>(store);
            Get.put<PickerController>(picker);
            Get.put<HomeController>(
              HomeController(
                localStore: store,
                picker: picker,
                config: config,
              ),
            );
          }),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SavesIndicator), findsOneWidget);
      await tester.tap(find.byType(SavesIndicator));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Should be on paywall screen
      expect(Get.currentRoute, Routes.paywall);
      expect(
        find.text('Keep this photo — and every photo after it.'),
        findsOneWidget,
      );
    });

    testWidgets('Entry Point (a): Home saves line tap when saves > 0 does NOT open paywall', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(780, 1688);
      addTearDown(tester.view.reset);

      final store = StubLocalStore(used: 3); // 7 saves left
      final picker = PickerController();

      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          theme: AppTheme.light(),
          initialRoute: Routes.home,
          getPages: AppPages.pages,
          initialBinding: BindingsBuilder<void>(() {
            Get.put<AppConfig>(config);
            Get.put<LocalStore>(store);
            Get.put<PickerController>(picker);
            Get.put<HomeController>(
              HomeController(
                localStore: store,
                picker: picker,
                config: config,
              ),
            );
          }),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SavesIndicator), findsOneWidget);

      // Tap saves line
      await tester.tap(find.byType(SavesIndicator));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Remains on home
      expect(Get.currentRoute, Routes.home);
    });

    testWidgets('Entry Point (b): Result Save button tap when saves = 0 opens paywall with photo args', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(780, 1688);
      addTearDown(tester.view.reset);

      final store = StubLocalStore(used: 10); // 0 saves left
      const origPath = '/mock/orig.png';
      const resPath = '/mock/res.png';

      final outcome = ProcessingOutcome(
        originalPath: origPath,
        resultPath: resPath,
        personsDetected: 1,
        keeperIds: const <int>[],
        removedIds: const <int>[1],
        totalSeconds: 1.0,
        engineUsed: 'mat',
      );

      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          theme: AppTheme.light(),
          initialRoute: Routes.home,
          getPages: <GetPage<dynamic>>[
            GetPage<dynamic>(
              name: Routes.home,
              page: () => const Scaffold(body: Text('HOME')),
            ),
            ...AppPages.pages.where((p) => p.name != Routes.home),
          ],
          initialBinding: BindingsBuilder<void>(() {
            Get.put<AppConfig>(config);
            Get.put<LocalStore>(store);
          }),
        ),
      );
      await tester.pump();

      Get.offNamed<void>(Routes.result, arguments: outcome);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Trigger Save
      final resultCtrl = Get.find<ResultController>();
      expect(resultCtrl.savesLeft.value, 0);

      await resultCtrl.save();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Replaces info dialog with Paywall navigation
      expect(Get.currentRoute, Routes.paywall);
      expect(
        find.text('Keep this photo — and every photo after it.'),
        findsOneWidget,
      );
      expect(find.text('This photo stays available for 24 hours.'), findsOneWidget);
    });
  });
}
