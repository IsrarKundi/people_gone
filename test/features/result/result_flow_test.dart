import 'dart:async';
import 'dart:io';
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
import 'package:people_gone/features/processing/model/processing_args.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/storage/local_store.dart';

import '../processing/processing_flow_test.dart' show pngBytes;

class TrackingStore implements LocalStore {
  int used = 0;
  bool galleryFails = false;
  final List<String> galleryPaths = <String>[];
  int consumeCalls = 0;
  final List<HistoryEntry> added = <HistoryEntry>[];


  GatewayJobRecord? gatewayJobRecord;

  @override
  Future<Result<void>> saveGatewayJob(GatewayJobRecord record) async {
    gatewayJobRecord = record;
    return const Success<void>(null);
  }

  @override
  Future<Result<GatewayJobRecord?>> gatewayJob() async =>
      Success<GatewayJobRecord?>(gatewayJobRecord);

  @override
  Future<Result<void>> clearGatewayJob() async {
    gatewayJobRecord = null;
    return const Success<void>(null);
  }
  @override
  Future<Result<int>> freeSavesUsed() async => Success<int>(used);

  @override
  Future<Result<DateTime>> freeSavesResetDate() async =>
      Success<DateTime>(DateTime.utc(2026, 11, 1));

  @override
  Future<Result<void>> consumeFreeSave() async {
    consumeCalls++;
    used++;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> saveToGallery(String localPath) async {
    if (galleryFails) {
      return const Failure<void>(
        AppFailure(code: 'gallery', userMessageKey: AppStrings.errorSaveFailed),
      );
    }
    galleryPaths.add(localPath);
    return const Success<void>(null);
  }

  @override
  Future<Result<String>> adoptIntoHistory(
    String sessionPath,
    String id,
  ) async => Success<String>('/history/$id.jpg');

  @override
  Future<Result<String>> adoptOriginalIntoHistory(
    String originalPath,
    String id,
  ) async => Success<String>('/history/${id}_orig.jpg');

  @override
  Future<Result<void>> addHistory(HistoryEntry entry) async {
    added.add(entry);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryEntry>>> history() async =>
      Success<List<HistoryEntry>>(added);

  @override
  Future<Result<void>> deleteHistory(String id) async =>
      const Success<void>(null);

  @override
  Future<Result<String>> writeSessionResult(Uint8List bytes) async =>
      const Success<String>('/session/result.jpg');

  @override
  Future<Result<int?>> acceptedConsentVersion() async => const Success<int?>(1);

  @override
  Future<Result<void>> setAcceptedConsentVersion(int version) async =>
      const Success<void>(null);
}

class FakeProcessingApi implements ProcessingApi {
  List<int>? lastKeepIds;
  int calls = 0;

  @override
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    void Function(double fraction)? onUploadProgress,
  }) async {
    calls++;
    lastKeepIds = keepIds;
    return Success<ProcessedPhoto>(
      ProcessedPhoto(
        resultBytes: pngBytes,
        personsDetected: 2,
        keeperIds: keepIds ?? <int>[0],
        removedIds: <int>[1],
        cropsInpainted: 1,
        totalSeconds: 1.0,
        engineUsed: 'mat',
      ),
    );
  }

  @override
  Future<Result<DetectionProposal>> detectPersons({
    required String localPath,
    void Function(double fraction)? onUploadProgress,
  }) async {
    return Success<DetectionProposal>(
      DetectionProposal(
        photoPath: localPath,
        personsDetected: 2,
        keeperIds: const <int>[0],
        removedIds: const <int>[1],
        persons: const <DetectedPerson>[
          DetectedPerson(id: 0, box: <int>[10, 10, 50, 90], score: 0.95, isKeeper: true),
          DetectedPerson(id: 1, box: <int>[60, 20, 90, 80], score: 0.85, isKeeper: false),
        ],
        inputDimensions: const <int>[100, 100],
      ),
    );
  }

  @override
  void cancelOngoing() {}

  @override
  Future<Result<TouchupOutcome>> touchupPhoto({
    required String localPath,
    required Uint8List maskPng,
    void Function(double fraction)? onUploadProgress,
  }) async => const Failure<TouchupOutcome>(
    AppFailure(code: 'not_implemented', userMessageKey: AppStrings.errorGeneric),
  );

  @override
  Future<Result<SaveCreditDecision>> consumeSaveCredit({
    required String idempotencyKey,
  }) async => const Failure<SaveCreditDecision>(
    AppFailure(code: 'not_implemented', userMessageKey: AppStrings.errorGeneric),
  );

  @override
  Future<Result<void>> refundSaveCredit({
    required String idempotencyKey,
  }) async => const Failure<void>(
    AppFailure(code: 'not_implemented', userMessageKey: AppStrings.errorGeneric),
  );
}

class TestBinding extends Bindings {
  TestBinding(this.store, this.api, this.config);
  final LocalStore store;
  final ProcessingApi api;
  final AppConfig config;

  @override
  void dependencies() {
    Get.put<LocalStore>(store);
    Get.put<ProcessingApi>(api);
    Get.put<AppConfig>(config);
  }
}

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
    tempDir = await Directory.systemTemp.createTemp('pg_result_test');
    original = File('${tempDir.path}/original.png')..writeAsBytesSync(pngBytes);
    resultFile = File('${tempDir.path}/result.png')..writeAsBytesSync(pngBytes);
    store = TrackingStore();
    api = FakeProcessingApi();
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  ProcessingOutcome outcome({List<int> removed = const <int>[1]}) {
    return ProcessingOutcome(
      originalPath: original.path,
      resultPath: resultFile.path,
      personsDetected: 2,
      keeperIds: const <int>[0],
      removedIds: removed,
      totalSeconds: 4.2,
      engineUsed: 'mat',
    );
  }

  Future<void> pumpResult(WidgetTester tester) async {
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
    Get.offNamed<void>(Routes.result, arguments: outcome());
    await tester.pump();
    // Let the page transition finish so taps hit their targets.
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('save: meter line first, then gallery+history+one credit', (
    tester,
  ) async {
    store.used = 3;
    await pumpResult(tester);
    expect(
      find.text('Saving uses 1 free save · 6 left after this one'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save photo'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.galleryPaths, <String>[resultFile.path]);
    expect(store.consumeCalls, 1);
    expect(store.added, hasLength(1));
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Saved to your photos'), findsOneWidget);
    // Flush the snackbar before teardown.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('out of saves: Save explains instead of consuming', (
    tester,
  ) async {
    store.used = 10;
    await pumpResult(tester);
    expect(find.text("You've used this month's free saves."), findsOneWidget);
    await tester.tap(find.text('Save photo'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No free saves left'), findsOneWidget);
    expect(store.galleryPaths, isEmpty);
    expect(store.consumeCalls, 0);
    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('gallery failure: nothing consumed, plain error shown', (
    tester,
  ) async {
    store.galleryFails = true;
    await pumpResult(tester);
    await tester.tap(find.text('Save photo'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.consumeCalls, 0);
    expect(store.added, isEmpty);
    expect(find.text('Save photo'), findsOneWidget);
    expect(
      find.text("That photo couldn't be saved. Please try again."),
      findsOneWidget,
    );
    // Flush the snackbar before teardown.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('keeper correction re-runs keeping the chosen person', (
    tester,
  ) async {
    await pumpResult(tester);
    await tester.tap(find.text('Kept the wrong person?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Person 1 — protected'), findsOneWidget);
    expect(find.text('Person 2 — will be removed'), findsOneWidget);
    await tester.tap(find.text('Keep this person instead'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(api.calls, 1);
    expect(api.lastKeepIds, <int>[1]);
  });

  testWidgets('compare toggle shows Before/After slider labels', (
    tester,
  ) async {
    await pumpResult(tester);
    await tester.tap(find.byIcon(Icons.compare));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
  });

  /// Lets the photo's intrinsic size resolve (real file IO) so
  /// PhotoSurface reports the true photo band.
  Future<void> settlePhotoBand(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  /// Primes the image cache with the exact provider ResultView uses.
  /// File-image loads started inside the fake-async zone never
  /// resolve (the capture harness hit the same trap), so the load
  /// must complete in runAsync BEFORE the app mounts.
  Future<void> primePhoto(WidgetTester tester, String path) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.expand()));
    final context = tester.element(find.byType(SizedBox));
    final provider = ResizeImage(FileImage(File(path)), width: 800);
    await tester.runAsync(() async {
      final stream = provider.resolve(createLocalImageConfiguration(context));
      final done = Completer<void>();
      late ImageStreamListener listener;
      listener = ImageStreamListener((_, _) {
        stream.removeListener(listener);
        done.complete();
      }, onError: (_, _) => done.complete());
      stream.addListener(listener);
      await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    });
  }

  Finder chromeButton(IconData icon) =>
      find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton));

  testWidgets('chrome is exactly 48dp, pinned to the photo band (F3)', (
    tester,
  ) async {
    await primePhoto(tester, resultFile.path);
    await pumpResult(tester);
    await settlePhotoBand(tester);
    final close = chromeButton(Icons.close);
    expect(tester.getSize(close), const Size(48, 48));
    final rect = tester.getRect(close);
    // The 1x1 test photo pillarboxes in the wide photo area, so a
    // band-pinned button sits far from the screen edge (the old
    // layout floated it at the area's corner: left 16, top 16).
    expect(rect.left, greaterThan(100));
    expect(rect.top, lessThan(16));
  });

  testWidgets('compare pills sit below the chrome row (F7)', (tester) async {
    await pumpResult(tester);
    await tester.tap(find.byIcon(Icons.compare));
    await tester.pump(const Duration(milliseconds: 50));
    await settlePhotoBand(tester);
    final chrome = tester.getRect(chromeButton(Icons.close));
    final before = tester.getRect(find.text('Before'));
    expect(before.top, greaterThanOrEqualTo(chrome.bottom - 1));
  });
}
