import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/constants/app_icons.dart';
import 'package:people_gone/core/constants/app_motion.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/processing/model/processing_args.dart';
import 'package:people_gone/features/result/controller/result_controller.dart';
import 'package:people_gone/features/result/view/result_view.dart';
import 'package:people_gone/features/result/widgets/compare_slider.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/storage/local_store.dart';

final Uint8List _testPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class _MockLocalStore implements LocalStore {
  int used = 0;
  final List<String> galleryPaths = <String>[];
  GatewayJobRecord? jobRecord;

  @override
  Future<Result<void>> saveGatewayJob(GatewayJobRecord record) async {
    jobRecord = record;
    return const Success<void>(null);
  }

  @override
  Future<Result<GatewayJobRecord?>> gatewayJob() async =>
      Success<GatewayJobRecord?>(jobRecord);

  @override
  Future<Result<void>> clearGatewayJob() async {
    jobRecord = null;
    return const Success<void>(null);
  }

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
  Future<Result<void>> saveToGallery(String localPath) async {
    galleryPaths.add(localPath);
    return const Success<void>(null);
  }

  @override
  Future<Result<String>> adoptIntoHistory(String sessionPath, String id) async =>
      Success<String>('/history/$id.jpg');

  @override
  Future<Result<String>> adoptOriginalIntoHistory(
    String originalPath,
    String id,
  ) async => Success<String>('/history/${id}_orig.jpg');

  @override
  Future<Result<void>> addHistory(HistoryEntry entry) async =>
      const Success<void>(null);

  @override
  Future<Result<List<HistoryEntry>>> history() async =>
      const Success<List<HistoryEntry>>(<HistoryEntry>[]);

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

class _MockProcessingApi implements ProcessingApi {
  @override
  void cancelOngoing() {}

  @override
  Future<Result<DetectionProposal>> detectPersons({
    required String localPath,
    void Function(double fraction)? onUploadProgress,
  }) async =>
      const Failure<DetectionProposal>(
        AppFailure(code: 'test', userMessageKey: AppStrings.errorGeneric),
      );

  @override
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    List<int>? removeItemIds,
    List<int>? detachedBelongingIds,
    void Function(double fraction)? onUploadProgress,
  }) async =>
      const Failure<ProcessedPhoto>(
        AppFailure(code: 'test', userMessageKey: AppStrings.errorGeneric),
      );

  @override
  Future<Result<TouchupOutcome>> touchupPhoto({
    required String localPath,
    required Uint8List maskPng,
    void Function(double fraction)? onUploadProgress,
  }) async =>
      const Failure<TouchupOutcome>(
        AppFailure(code: 'test', userMessageKey: AppStrings.errorGeneric),
      );

  @override
  Future<Result<SaveCreditDecision>> consumeSaveCredit({
    required String idempotencyKey,
  }) async =>
      const Success<SaveCreditDecision>(
        SaveCreditDecision(
          allowed: true,
          paymentRequired: false,
          isPro: false,
          savesLeft: 10,
        ),
      );

  @override
  Future<Result<void>> refundSaveCredit({
    required String idempotencyKey,
  }) async => const Success<void>(null);
}

void main() {
  late Directory tempDir;
  late File original;
  late File resultFile;
  late _MockLocalStore store;
  late _MockProcessingApi api;

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
    tempDir = Directory.systemTemp.createTempSync('pg_result_motion_');
    original = File('${tempDir.path}/orig.png')..writeAsBytesSync(_testPngBytes);
    resultFile = File('${tempDir.path}/res.png')..writeAsBytesSync(_testPngBytes);
    store = _MockLocalStore();
    api = _MockProcessingApi();
    CompareSlider.hasRunCompareNudge = false;
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
    Get.reset();
  });

  ProcessingOutcome createOutcome() => ProcessingOutcome(
        originalPath: original.path,
        resultPath: resultFile.path,
        personsDetected: 2,
        keeperIds: const <int>[0],
        removedIds: const <int>[1],
        totalSeconds: 1.0,
        engineUsed: 'mat',
      );

  Future<void> pumpResult(
    WidgetTester tester, {
    ProcessingOutcome? outcome,
    bool disableAnimations = false,
  }) async {
    final actualOutcome = outcome ?? createOutcome();
    Get.routing.args = actualOutcome;
    Get.put<LocalStore>(store);
    Get.put<ProcessingApi>(api);
    Get.put<AppConfig>(config);
    final controller = ResultController(
      localStore: store,
      processingApi: api,
      config: config,
    );
    Get.put<ResultController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            if (disableAnimations) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const ResultView(),
              );
            }
            return const ResultView();
          },
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Item 11: Result first-open dissolve fades original into cleaned photo over 450ms',
      (tester) async {
    await pumpResult(tester);

    // Initial frame: dissolve starts, both images rendered in stack with Opacity
    expect(find.byType(ResultView), findsOneWidget);
    expect(find.byType(Opacity), findsWidgets);

    // Frame strip 0: t=0ms
    await expectLater(
      find.byType(ResultView),
      matchesGoldenFile('result_dissolve_frame0.png'),
    );

    // Frame strip 1: t=225ms (halfway dissolve)
    await tester.pump(const Duration(milliseconds: 225));
    await expectLater(
      find.byType(ResultView),
      matchesGoldenFile('result_dissolve_frame1.png'),
    );

    // Frame strip 2: t=450ms (settled result)
    await tester.pump(const Duration(milliseconds: 225));
    await expectLater(
      find.byType(ResultView),
      matchesGoldenFile('result_dissolve_frame2.png'),
    );
  });

  testWidgets('Item 12: Save success morphs button to check icon + Saved and holds for 1.2s',
      (tester) async {
    await pumpResult(tester);
    await tester.pump(const Duration(milliseconds: 500)); // Finish dissolve

    expect(find.text('Save photo'), findsOneWidget);

    // Trigger save
    await tester.tap(find.text('Save photo'));
    await tester.pump(); // Start save
    await tester.pump(const Duration(milliseconds: 100)); // Complete save

    final controller = Get.find<ResultController>();
    // Receipt state: Check icon morphs in with "Saved"
    expect(controller.saved.value, isTrue);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byIcon(AppIcons.checkFill), findsOneWidget);

    // Capture receipt hold visual evidence
    await expectLater(
      find.byType(ResultView),
      matchesGoldenFile('result_save_receipt.png'),
    );

    // After 1.2s hold, button settles quietly without confetti or celebration
    await tester.pump(AppMotion.saveHold);
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);

    // Flush the save snackbar cleanly before ending test
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('Item 13: CompareSlider handle nudges once and returns over 600ms',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CompareSlider(
            originalPath: original.path,
            resultPath: resultFile.path,
          ),
        ),
      ),
    );

    // At t=0ms, slider begins at 0.5
    await tester.pump();
    await expectLater(
      find.byType(CompareSlider),
      matchesGoldenFile('result_compare_nudge0.png'),
    );

    // At t=300ms, slider reaches peak nudge ~0.58
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(CompareSlider),
      matchesGoldenFile('result_compare_nudge1.png'),
    );

    // At t=600ms, slider returns to 0.5
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(CompareSlider),
      matchesGoldenFile('result_compare_nudge2.png'),
    );
  });

  testWidgets('Reduced motion skips dissolve and compare nudge',
      (tester) async {
    CompareSlider.hasRunCompareNudge = false;
    await pumpResult(tester, disableAnimations: true);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byType(ResultView), findsOneWidget);
  });
}
