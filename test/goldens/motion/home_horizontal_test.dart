import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/core/widgets/primary_button.dart';
import 'package:people_gone/features/home/view/home_view.dart';
import 'package:people_gone/features/home/widgets/earlier_cleans_tray.dart';
import 'package:people_gone/features/home/widgets/featured_clean_card.dart';
import 'package:people_gone/features/home/widgets/home_job_banner.dart';
import 'package:people_gone/features/home/widgets/interactive_demo_card.dart';
import 'package:people_gone/features/home/widgets/saves_indicator.dart';
import 'package:people_gone/features/picker/controller/picker_controller.dart';
import 'package:people_gone/services/processing/job_tracker.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/storage/local_store.dart';

final Uint8List _fakeBytes = Uint8List(10);

class _FakeStore implements LocalStore {
  int used = 0;
  List<HistoryEntry> entries = <HistoryEntry>[];

  @override
  Future<Result<int>> freeSavesUsed() async => Success<int>(used);

  @override
  Future<Result<DateTime>> freeSavesResetDate() async =>
      Success<DateTime>(DateTime.utc(2026, 11, 1));

  @override
  Future<Result<List<HistoryEntry>>> history() async =>
      Success<List<HistoryEntry>>(entries);

  @override
  Future<Result<GatewayJobRecord?>> gatewayJob() async =>
      const Success<GatewayJobRecord?>(null);

  @override
  Future<Result<void>> clearGatewayJob() async => const Success<void>(null);

  @override
  Future<Result<int?>> acceptedConsentVersion() async => const Success<int?>(1);

  @override
  Future<Result<void>> setAcceptedConsentVersion(int v) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> addHistory(HistoryEntry entry) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> deleteHistory(String id) async =>
      const Success<void>(null);

  @override
  Future<Result<String>> adoptIntoHistory(String s, String id) async =>
      Success<String>(s);

  @override
  Future<Result<String>> adoptOriginalIntoHistory(String o, String id) async =>
      Success<String>(o);

  @override
  Future<Result<void>> saveToGallery(String p) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> consumeFreeSave() async => const Success<void>(null);

  @override
  Future<Result<bool>> introSeen() async => const Success<bool>(true);

  @override
  Future<Result<void>> setIntroSeen() async => const Success<void>(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProcessingApi implements ProcessingApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestBinding extends Bindings {
  _TestBinding(this.store);
  final LocalStore store;

  @override
  void dependencies() {
    Get.put<LocalStore>(store);
    Get.put<PickerController>(
      PickerController(
        pickImage: () async => XFile('/tmp/fake.jpg'),
        maxBytes: 10 * 1024 * 1024,
      ),
    );
    Get.put<ProcessingApi>(_FakeProcessingApi());
    Get.put<AppConfig>(
      const AppConfig(
        apiBaseUrl: 'https://worker.test',
        providerDisplayName: "PeopleGone's processing servers",
        consentVersion: 1,
        supportEmail: 'support@example.com',
        privacyPolicyUrl: 'https://example.invalid/privacy',
        useGateway: false,
        supabaseUrl: '',
        supabaseAnonKey: '',
      ),
    );
  }
}

void main() {
  setUp(() {
    Get.reset();
    InteractiveDemoCard.hasRunTeachingSweep = true;
  });

  tearDown(() {
    Get.reset();
    JobTracker.instance.clear();
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    required _FakeStore store,
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(780, 1688);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        debugShowCheckedModeBanner: false,
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        initialBinding: _TestBinding(store),
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'Task 2: Home layout top-to-bottom order (Demo -> Pick button -> Saves -> History)',
    (tester) async {
      final store = _FakeStore();
      await pumpHome(tester, store: store);

      // Verify all components exist
      final demoFinder = find.byType(InteractiveDemoCard);
      final pickBtnFinder = find.byType(PrimaryButton);
      final emptyLineFinder = find.text(
        'Remove background people from a photo. Your subject stays untouched.',
      );
      final savesFinder = find.byType(SavesIndicator);

      expect(demoFinder, findsOneWidget);
      expect(pickBtnFinder, findsOneWidget);
      expect(emptyLineFinder, findsOneWidget);
      expect(savesFinder, findsOneWidget);

      // Verify geometry: 1. Demo at top, 2. Pick button directly below, 3. Saves below
      final demoRect = tester.getRect(demoFinder);
      final pickRect = tester.getRect(pickBtnFinder);
      final emptyLineRect = tester.getRect(emptyLineFinder);
      final savesRect = tester.getRect(savesFinder);

      // 1. Demo is a modest horizontal card: height is exactly 180dp
      expect(demoRect.height, 180.0);

      // 2. Demo is ABOVE pick button
      expect(demoRect.bottom, lessThanOrEqualTo(pickRect.top));

      // Existing text is directly underneath the button
      expect(pickRect.bottom, lessThanOrEqualTo(emptyLineRect.top));

      // 3. Saves fact is below the text
      expect(emptyLineRect.bottom, lessThanOrEqualTo(savesRect.top));

      // Capture light mode evidence
      await expectLater(
        find.byType(HomeView),
        matchesGoldenFile('home_horizontal_light.png'),
      );
    },
  );

  testWidgets('Task 2: Home layout in dark mode captures evidence', (
    tester,
  ) async {
    final store = _FakeStore();
    await pumpHome(tester, store: store, mode: ThemeMode.dark);

    expect(find.byType(InteractiveDemoCard), findsOneWidget);
    expect(find.byType(PrimaryButton), findsOneWidget);

    await expectLater(
      find.byType(HomeView),
      matchesGoldenFile('home_horizontal_dark.png'),
    );
  });

  testWidgets('Task 2: Home layout with active job banner and history', (
    tester,
  ) async {
    final temp = Directory.systemTemp.createTempSync('pg_test');
    final dummy = File('${temp.path}/dummy.jpg')..writeAsBytesSync(_fakeBytes);
    addTearDown(() => temp.deleteSync(recursive: true));

    final store = _FakeStore()
      ..entries = <HistoryEntry>[
        HistoryEntry(
          id: 'h1',
          localPath: dummy.path,
          savedAt: DateTime(2026, 10, 15),
        ),
        HistoryEntry(
          id: 'h2',
          localPath: dummy.path,
          savedAt: DateTime(2026, 10, 14),
        ),
      ];

    JobTracker.instance.trackStarted(photoPath: dummy.path);

    await pumpHome(tester, store: store);

    final demoRect = tester.getRect(find.byType(InteractiveDemoCard));
    final pickRect = tester.getRect(find.byType(PrimaryButton));
    final savesRect = tester.getRect(find.byType(SavesIndicator));
    final bannerRect = tester.getRect(find.byType(HomeJobBanner));
    final historySectionRect = tester.getRect(find.byType(FeaturedCleanCard));

    // Order: Demo -> Pick -> Saves -> Job Banner -> History
    expect(demoRect.bottom, lessThanOrEqualTo(pickRect.top));
    expect(pickRect.bottom, lessThanOrEqualTo(savesRect.top));
    expect(savesRect.bottom, lessThanOrEqualTo(bannerRect.top));
    expect(bannerRect.bottom, lessThanOrEqualTo(historySectionRect.top));

    expect(find.byType(EarlierCleansTray), findsOneWidget);
  });
}
