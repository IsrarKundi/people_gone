import 'dart:async';
import 'dart:convert';
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

/// 1x1 PNG so Image.file decodes cleanly in tests.
final Uint8List pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class FakeProcessingApi implements ProcessingApi {
  Result<ProcessedPhoto> next = Failure<ProcessedPhoto>(
    const AppFailure(
      code: 'server',
      userMessageKey: AppStrings.errorProcessingFailed,
    ),
  );
  Completer<void>? gate;
  void Function(double)? progressSeen;
  int calls = 0;
  List<int>? lastKeepIds;
  List<int>? lastRemoveItemIds;
  List<int>? lastDetachedBelongingIds;

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
    lastRemoveItemIds = removeItemIds;
    lastDetachedBelongingIds = detachedBelongingIds;
    if (onUploadProgress != null) {
      progressSeen = onUploadProgress;
      onUploadProgress(0.5);
    }
    if (gate != null) await gate!.future;
    if (onUploadProgress != null) onUploadProgress(1.0);
    return next;
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

class FakeLocalStore implements LocalStore {
  FakeLocalStore(this.dir);
  final Directory dir;


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
  Future<Result<String>> writeSessionResult(Uint8List bytes) async {
    final file = File('${dir.path}/session_result.jpg');
    file.writeAsBytesSync(bytes);
    return Success<String>(file.path);
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
  Future<Result<String>> adoptIntoHistory(
    String sessionPath,
    String id,
  ) async => Success<String>(sessionPath);

  @override
  Future<Result<String>> adoptOriginalIntoHistory(
    String originalPath,
    String id,
  ) async => Success<String>(originalPath);

  @override
  Future<Result<void>> saveToGallery(String localPath) async =>
      const Success<void>(null);

  @override
  Future<Result<int>> freeSavesUsed() async => const Success<int>(0);

  @override
  Future<Result<DateTime>> freeSavesResetDate() async =>
      Success<DateTime>(DateTime.utc(2026, 11, 1));

  @override
  Future<Result<void>> consumeFreeSave() async => const Success<void>(null);

  @override
  Future<Result<int?>> acceptedConsentVersion() async => const Success<int?>(1);

  @override
  Future<Result<void>> setAcceptedConsentVersion(int version) async =>
      const Success<void>(null);
}

class TestBinding extends Bindings {
  TestBinding(this.api, this.store);
  final ProcessingApi api;
  final LocalStore store;

  @override
  void dependencies() {
    Get.put<ProcessingApi>(api);
    Get.put<LocalStore>(store);
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

ProcessedPhoto photo({required List<int> removed, required int detected}) {
  return ProcessedPhoto(
    resultBytes: pngBytes,
    personsDetected: detected,
    keeperIds: const <int>[0],
    removedIds: removed,
    cropsInpainted: removed.length,
    totalSeconds: 1.5,
    engineUsed: 'mat',
  );
}

void main() {
  late Directory tempDir;
  late File picked;
  late FakeProcessingApi api;
  late FakeLocalStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_flow_test');
    picked = File('${tempDir.path}/picked.png');
    picked.writeAsBytesSync(pngBytes);
    api = FakeProcessingApi();
    store = FakeLocalStore(tempDir);
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpFlow(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        initialBinding: TestBinding(api, store),
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
    Get.toNamed<void>(
      Routes.processing,
      arguments: ProcessingArgs(photoPath: picked.path),
    );
    await tester.pump();
  }

  testWidgets('success: uploads, processes, lands on the result summary', (
    tester,
  ) async {
    api.next = Success<ProcessedPhoto>(photo(removed: <int>[1], detected: 2));
    await pumpFlow(tester);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text('1 of 2 people removed. Your subject stays untouched.'),
      findsOneWidget,
    );
    expect(api.calls, 1);
  });

  testWidgets('failure: plain-language error, Retry re-runs and succeeds', (
    tester,
  ) async {
    await pumpFlow(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text("We couldn't clean this photo. Please try again."),
      findsOneWidget,
    );
    api.next = Success<ProcessedPhoto>(photo(removed: <int>[1], detected: 2));
    await tester.tap(find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.calls, 2);
    expect(
      find.text('1 of 2 people removed. Your subject stays untouched.'),
      findsOneWidget,
    );
  });

  testWidgets('upload stage shows the real percentage while sending', (
    tester,
  ) async {
    api.gate = Completer<void>();
    api.next = Success<ProcessedPhoto>(photo(removed: <int>[1], detected: 2));
    await pumpFlow(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Uploading your photo… 50%'), findsOneWidget);
    api.gate!.complete();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('people removed'), findsOneWidget);
  });

  testWidgets('nobody removed: result shows the plain message', (tester) async {
    api.next = Success<ProcessedPhoto>(photo(removed: <int>[], detected: 1));
    await pumpFlow(tester);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text("There's nobody in the background to remove."),
      findsOneWidget,
    );
  });
}
