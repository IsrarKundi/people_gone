import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/constants/app_icons.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/brush/model/brush_args.dart';
import 'package:people_gone/features/processing/model/processing_args.dart';
import 'package:people_gone/features/result/controller/result_controller.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/storage/local_store.dart';

import '../processing/processing_flow_test.dart' show pngBytes;

class TrackingStore implements LocalStore {
  int used = 0;
  bool galleryFails = false;
  bool adoptFails = false;
  int galleryAttempts = 0;
  List<String>? sharedLog;
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
    sharedLog?.add('localConsume');
    consumeCalls++;
    used++;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> saveToGallery(String localPath) async {
    galleryAttempts++;
    sharedLog?.add('gallery');
    if (galleryFails) {
      return const Failure<void>(
        AppFailure(code: 'gallery', userMessageKey: AppStrings.errorSaveFailed),
      );
    }
    galleryPaths.add(localPath);
    return const Success<void>(null);
  }

  @override
  Future<Result<String>> adoptIntoHistory(String sessionPath, String id) async {
    sharedLog?.add('adopt');
    if (adoptFails) {
      return const Failure<String>(
        AppFailure(code: 'history', userMessageKey: AppStrings.errorSaveFailed),
      );
    }
    return Success<String>('/history/$id.jpg');
  }

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

  // Configurable gateway behaviour (save-credit gate + touch-up).
  SaveCreditDecision consumeDecision = const SaveCreditDecision(
    allowed: true,
    paymentRequired: false,
    isPro: false,
    savesLeft: 9,
  );
  bool consumeFails = false;
  final List<String> consumeKeys = <String>[];
  final List<String> refundKeys = <String>[];
  int refundCalls = 0;
  List<String>? sharedLog;
  Result<TouchupOutcome>? touchupResult;
  int touchupCalls = 0;
  Uint8List? lastMask;
  String? lastTouchupPath;

  @override
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    List<int>? removeItemIds,
    List<int>? detachedBelongingIds,
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
          DetectedPerson(
            id: 0,
            box: <int>[10, 10, 50, 90],
            score: 0.95,
            isKeeper: true,
          ),
          DetectedPerson(
            id: 1,
            box: <int>[60, 20, 90, 80],
            score: 0.85,
            isKeeper: false,
          ),
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
  }) async {
    touchupCalls++;
    lastTouchupPath = localPath;
    lastMask = maskPng;
    onUploadProgress?.call(1.0);
    return touchupResult ??
        const Failure<TouchupOutcome>(
          AppFailure(
            code: 'not_implemented',
            userMessageKey: AppStrings.errorGeneric,
          ),
        );
  }

  @override
  Future<Result<SaveCreditDecision>> consumeSaveCredit({
    required String idempotencyKey,
  }) async {
    sharedLog?.add('consume');
    consumeKeys.add(idempotencyKey);
    if (consumeFails) {
      return const Failure<SaveCreditDecision>(
        AppFailure(code: 'gateway', userMessageKey: AppStrings.errorGeneric),
      );
    }
    return Success<SaveCreditDecision>(consumeDecision);
  }

  @override
  Future<Result<void>> refundSaveCredit({
    required String idempotencyKey,
  }) async {
    sharedLog?.add('refund');
    refundCalls++;
    refundKeys.add(idempotencyKey);
    return const Success<void>(null);
  }
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

  const gatewayConfig = AppConfig(
    apiBaseUrl: 'https://worker.test',
    providerDisplayName: "PeopleGone's processing servers",
    consentVersion: 1,
    supportEmail: 'support@example.com',
    privacyPolicyUrl: 'https://example.invalid/privacy',
    useGateway: true,
    supabaseUrl: '',
    supabaseAnonKey: '',
  );

  var stubReturnPath = '';

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

  ProcessingOutcome reflectionOutcome() {
    return ProcessingOutcome(
      originalPath: original.path,
      resultPath: resultFile.path,
      personsDetected: 2,
      keeperIds: const <int>[0],
      removedIds: const <int>[1],
      totalSeconds: 4.2,
      engineUsed: 'mat',
      reflectionWarning: true,
      reflectionRegions: const <List<int>>[
        <int>[100, 500, 300, 900],
      ],
    );
  }

  Future<void> pumpResult(
    WidgetTester tester, {
    AppConfig? configOverride,
    ProcessingOutcome? outcomeOverride,
    bool stubBrush = false,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        initialBinding: TestBinding(store, api, configOverride ?? config),
        initialRoute: Routes.home,
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(
            name: Routes.home,
            page: () => const Scaffold(body: Text('HOME')),
          ),
          ...AppPages.pages.where(
            (p) =>
                p.name != Routes.home && (!stubBrush || p.name != Routes.brush),
          ),
          if (stubBrush)
            GetPage<dynamic>(
              name: Routes.brush,
              page: () => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Get.back<String>(result: stubReturnPath),
                    child: const Text('Stub brush return'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    await tester.pump();
    Get.offNamed<void>(Routes.result, arguments: outcomeOverride ?? outcome());
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
    await tester.tap(find.byIcon(AppIcons.arrowsLeftRight));
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
    final close = chromeButton(AppIcons.close);
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
    await tester.tap(find.byIcon(AppIcons.arrowsLeftRight));
    await tester.pump(const Duration(milliseconds: 50));
    await settlePhotoBand(tester);
    final chrome = tester.getRect(chromeButton(AppIcons.close));
    final before = tester.getRect(find.text('Before'));
    expect(before.top, greaterThanOrEqualTo(chrome.bottom - 1));
  });

  testWidgets('brush fix entry is visible on the result', (tester) async {
    await pumpResult(tester);
    expect(find.text('Brush fix'), findsOneWidget);
  });

  testWidgets('brush fix entry is visible when nobody was removed', (
    tester,
  ) async {
    await pumpResult(tester, outcomeOverride: outcome(removed: const <int>[]));
    expect(find.text('Brush fix'), findsOneWidget);
    expect(find.text('Pick another photo'), findsOneWidget);
  });

  testWidgets('reflection warning shows with its brush action (Phase D)', (
    tester,
  ) async {
    await pumpResult(tester, outcomeOverride: reflectionOutcome());
    expect(
      find.text('A reflection of a removed person may still be visible.'),
      findsOneWidget,
    );
    expect(find.text('Fix with brush'), findsOneWidget);
    // The controller exposes the region as the brush's guide.
    final controller = Get.find<ResultController>();
    expect(controller.reflectionWarning, isTrue);
    expect(controller.reflectionRegion, <int>[100, 500, 300, 900]);
  });

  testWidgets('no reflection warning without the flag (Phase D)', (
    tester,
  ) async {
    await pumpResult(tester);
    expect(
      find.text('A reflection of a removed person may still be visible.'),
      findsNothing,
    );
    expect(find.text('Fix with brush'), findsNothing);
  });

  testWidgets('reflection fix opens brush with the suggested region', (
    tester,
  ) async {
    // The warning block makes the action zone taller than the
    // default test surface; give this case a taller view.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    stubReturnPath = resultFile.path;
    await pumpResult(
      tester,
      outcomeOverride: reflectionOutcome(),
      stubBrush: true,
    );
    await tester.tap(find.text('Fix with brush'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Stub brush return'), findsOneWidget);
    final args = Get.arguments;
    expect(args, isA<BrushArgs>());
    expect((args as BrushArgs).suggestedRegion, <int>[100, 500, 300, 900]);
    expect(args.imagePath, resultFile.path);
  });

  testWidgets('gateway save: credit consumed BEFORE the gallery save', (
    tester,
  ) async {
    final orderLog = <String>[];
    api.sharedLog = orderLog;
    store.sharedLog = orderLog;
    await pumpResult(tester, configOverride: gatewayConfig);
    await tester.tap(find.text('Save photo'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.consumeKeys, hasLength(1));
    expect(orderLog.indexOf('consume'), lessThan(orderLog.indexOf('gallery')));
    expect(store.galleryPaths, <String>[resultFile.path]);
    expect(store.consumeCalls, 1);
    expect(api.refundCalls, 0);
    expect(Get.find<ResultController>().savesLeft.value, 9);
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('gateway payment_required: dialog, no gallery, no local use', (
    tester,
  ) async {
    api.consumeDecision = const SaveCreditDecision(
      allowed: false,
      paymentRequired: true,
      isPro: false,
      savesLeft: 0,
    );
    await pumpResult(tester, configOverride: gatewayConfig);
    await tester.tap(find.text('Save photo'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No free saves left'), findsOneWidget);
    expect(store.galleryAttempts, 0);
    expect(store.galleryPaths, isEmpty);
    expect(store.consumeCalls, 0);
    expect(api.refundCalls, 0);
    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('gateway consume failure: save never runs without the gate', (
    tester,
  ) async {
    api.consumeFails = true;
    await pumpResult(tester, configOverride: gatewayConfig);
    await tester.tap(find.text('Save photo'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.galleryAttempts, 0);
    expect(store.consumeCalls, 0);
    expect(api.refundCalls, 0);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('gateway gallery failure after consume refunds the credit', (
    tester,
  ) async {
    store.galleryFails = true;
    await pumpResult(tester, configOverride: gatewayConfig);
    await tester.tap(find.text('Save photo'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.consumeKeys, hasLength(1));
    expect(api.refundCalls, 1);
    expect(api.refundKeys, api.consumeKeys);
    expect(store.consumeCalls, 0);
    expect(
      find.text("That photo couldn't be saved. Please try again."),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('gateway history failure after consume refunds the credit', (
    tester,
  ) async {
    store.adoptFails = true;
    await pumpResult(tester, configOverride: gatewayConfig);
    await tester.tap(find.text('Save photo'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.refundCalls, 1);
    expect(api.refundKeys, api.consumeKeys);
    expect(store.consumeCalls, 0);
    expect(store.added, isEmpty);
    expect(
      find.text("That photo couldn't be saved. Please try again."),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('touch-up replaces the result and the next save re-gates', (
    tester,
  ) async {
    final touched = File('${tempDir.path}/touched.png')
      ..writeAsBytesSync(pngBytes);
    stubReturnPath = touched.path;
    await pumpResult(tester, configOverride: gatewayConfig, stubBrush: true);
    await tester.tap(find.text('Save photo'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.consumeKeys, hasLength(1));
    final firstKey = api.consumeKeys.single;
    final controller = Get.find<ResultController>();
    expect(controller.saved.value, isTrue);
    // Flush the save snackbar before navigating (it overlays the
    // route the Brush fix button pushes).
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Brush fix'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Stub brush return'), findsOneWidget);
    await tester.tap(find.text('Stub brush return'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.resultPath.value, touched.path);
    expect(controller.saved.value, isFalse);

    await tester.tap(find.text('Save photo'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.consumeKeys, hasLength(2));
    expect(api.consumeKeys.last, isNot(firstKey));
    expect(store.galleryPaths.last, touched.path);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
  });
}
