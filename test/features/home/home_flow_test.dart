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
import 'package:people_gone/features/home/widgets/earlier_cleans_tray.dart';
import 'package:people_gone/features/home/widgets/featured_clean_card.dart';
import 'package:people_gone/features/home/widgets/home_job_banner.dart';
import 'package:people_gone/features/picker/controller/picker_controller.dart';
import 'package:people_gone/services/processing/job_tracker.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/storage/local_store.dart';




import '../processing/processing_flow_test.dart' show pngBytes;

class FakeStore implements LocalStore {
  int? consent;
  int used = 0;
  List<HistoryEntry> entries = <HistoryEntry>[];

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
  Future<Result<int?>> acceptedConsentVersion() async => Success<int?>(consent);

  @override
  Future<Result<void>> setAcceptedConsentVersion(int version) async {
    consent = version;
    return const Success<void>(null);
  }

  @override
  Future<Result<int>> freeSavesUsed() async => Success<int>(used);

  @override
  Future<Result<DateTime>> freeSavesResetDate() async =>
      Success<DateTime>(DateTime.utc(2026, 11, 1));

  @override
  Future<Result<List<HistoryEntry>>> history() async =>
      Success<List<HistoryEntry>>(entries);

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
  Future<Result<void>> consumeFreeSave() async => const Success<void>(null);

  @override
  Future<Result<String>> writeSessionResult(Uint8List bytes) async =>
      const Success<String>('/session/result.jpg');

  bool isIntroSeen = true;

  @override
  Future<Result<bool>> introSeen() async => Success<bool>(isIntroSeen);

  @override
  Future<Result<void>> setIntroSeen() async {
    isIntroSeen = true;
    return const Success<void>(null);
  }
}

class FakeProcessingApi implements ProcessingApi {
  int calls = 0;
  int detectCalls = 0;

  @override
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    List<int>? removeItemIds,
    List<int>? detachedBelongingIds,
    void Function(double fraction)? onUploadProgress,
  }) async {
    calls++;
    return Success<ProcessedPhoto>(
      ProcessedPhoto(
        resultBytes: pngBytes,
        personsDetected: 2,
        keeperIds: const <int>[0],
        removedIds: const <int>[1],
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
    detectCalls++;
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
  }) async => const Failure<TouchupOutcome>(
    AppFailure(
      code: 'not_implemented',
      userMessageKey: AppStrings.errorGeneric,
    ),
  );

  @override
  Future<Result<SaveCreditDecision>> consumeSaveCredit({
    required String idempotencyKey,
  }) async => const Failure<SaveCreditDecision>(
    AppFailure(
      code: 'not_implemented',
      userMessageKey: AppStrings.errorGeneric,
    ),
  );

  @override
  Future<Result<void>> refundSaveCredit({
    required String idempotencyKey,
  }) async => const Failure<void>(
    AppFailure(
      code: 'not_implemented',
      userMessageKey: AppStrings.errorGeneric,
    ),
  );
}

class TestBinding extends Bindings {
  TestBinding(this.store, this.picker, this.api);
  final LocalStore store;
  final PickerController picker;
  final ProcessingApi api;

  @override
  void dependencies() {
    Get.put<LocalStore>(store);
    Get.put<PickerController>(picker);
    Get.put<ProcessingApi>(api);
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
  late Directory tempDir;
  late File picked;
  late FakeStore store;
  late FakeProcessingApi api;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_home_test');
    picked = File('${tempDir.path}/picked.png')..writeAsBytesSync(pngBytes);
    store = FakeStore();
    api = FakeProcessingApi();
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpHome(WidgetTester tester) async {
    final picker = PickerController(
      pickImage: () async => XFile(picked.path),
      maxBytes: 10 * 1024 * 1024,
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        initialBinding: TestBinding(store, picker, api),
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('first pick shows consent; continuing opens the proposal', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(find.text('Pick a photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    // Consent (S2) with the §11.2A wording and config provider name.
    expect(find.text('Before your photo is uploaded'), findsOneWidget);
    expect(
      find.textContaining("PeopleGone's processing servers"),
      findsOneWidget,
    );
    expect(find.text('Continue and upload my photo'), findsOneWidget);
    await tester.tap(find.text('Continue and upload my photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(store.consent, 1);
    // Review 04 F1: the golden path is pick -> consent -> Proposal,
    // whose analysing state calls detectPersons — processPhoto only
    // runs after the user confirms a proposal.
    expect(api.detectCalls, 1);
    expect(api.calls, 0);
  });

  testWidgets('consent already given: pick goes straight to the proposal', (
    tester,
  ) async {
    store.consent = 1;
    await pumpHome(tester);
    await tester.tap(find.text('Pick a photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Before your photo is uploaded'), findsNothing);
    expect(api.detectCalls, 1);
    expect(api.calls, 0);
  });

  testWidgets('history on Home shows the section, not the teaching line', (
    tester,
  ) async {
    store.entries = <HistoryEntry>[
      HistoryEntry(
        id: 'h1',
        localPath: picked.path,
        savedAt: DateTime(2026, 10, 13),
      ),
    ];
    await pumpHome(tester);
    expect(find.text('History'), findsWidgets);
    expect(
      find.text(
        'Remove background people from a photo. Your subject stays untouched.',
      ),
      findsNothing,
    );
  });

  testWidgets(
      'Home history shows the earlier cleans tray and no featured card', (
    tester,
  ) async {
    // Owner decision 2026-10-19: the FeaturedCleanCard slot was removed
    // from Home intentionally (its code stays commented out in
    // home_view.dart — do not restore it). The tray carries every recent
    // clean (Home passes history.take(10)).
    store.entries = <HistoryEntry>[
      for (var i = 0; i < 4; i++)
        HistoryEntry(
          id: 'h$i',
          localPath: picked.path,
          savedAt: DateTime(2026, 10, 13),
        ),
    ];
    await pumpHome(tester);
    expect(find.byType(FeaturedCleanCard), findsNothing);
    expect(find.byType(EarlierCleansTray), findsOneWidget);
    final tray = tester.widget<EarlierCleansTray>(find.byType(EarlierCleansTray));
    expect(tray.entries.length, 4);
  });

  testWidgets('Home shows active job banner when a background clean is processing', (
    tester,
  ) async {
    JobTracker.instance.trackStarted(photoPath: picked.path);
    await pumpHome(tester);
    expect(find.byType(HomeJobBanner), findsOneWidget);
    expect(find.text('Cleaning photo in background…'), findsOneWidget);
    JobTracker.instance.clear();
  });
}

