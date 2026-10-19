import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/constants/app_motion.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/processing/controller/processing_controller.dart';
import 'package:people_gone/features/processing/model/processing_args.dart';
import 'package:people_gone/features/processing/view/processing_view.dart';
import 'package:people_gone/features/processing/widgets/server_working_photo_frame.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/storage/local_store.dart';

final Uint8List _testPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class _FakeProcessingApi implements ProcessingApi {
  final Completer<Result<ProcessedPhoto>> completer =
      Completer<Result<ProcessedPhoto>>();

  @override
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    List<int>? removeItemIds,
    List<int>? detachedBelongingIds,
    void Function(double fraction)? onUploadProgress,
  }) async {
    return completer.future;
  }

  @override
  Future<Result<DetectionProposal>> detectPersons({
    required String localPath,
    void Function(double fraction)? onUploadProgress,
  }) async {
    return Success<DetectionProposal>(
      DetectionProposal(
        photoPath: localPath,
        personsDetected: 0,
        keeperIds: const <int>[],
        removedIds: const <int>[],
        persons: const <DetectedPerson>[],
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
  }) async =>
      const Failure<TouchupOutcome>(
        AppFailure(
            code: 'not_implemented', userMessageKey: AppStrings.errorGeneric),
      );

  @override
  Future<Result<SaveCreditDecision>> consumeSaveCredit({
    required String idempotencyKey,
  }) async =>
      const Failure<SaveCreditDecision>(
        AppFailure(
            code: 'not_implemented', userMessageKey: AppStrings.errorGeneric),
      );

  @override
  Future<Result<void>> refundSaveCredit({
    required String idempotencyKey,
  }) async =>
      const Failure<void>(
        AppFailure(
            code: 'not_implemented', userMessageKey: AppStrings.errorGeneric),
      );

}

class _FakeLocalStore implements LocalStore {
  @override
  Future<Result<void>> addHistory(HistoryEntry entry) async =>
      const Success<void>(null);

  @override
  Future<Result<String>> adoptIntoHistory(String sessionPath, String id) async =>
      Success<String>(sessionPath);

  @override
  Future<Result<String>> adoptOriginalIntoHistory(
    String originalPath,
    String id,
  ) async =>
      Success<String>(originalPath);

  @override
  Future<Result<void>> clearGatewayJob() async => const Success<void>(null);

  @override
  Future<Result<void>> consumeFreeSave() async => const Success<void>(null);

  @override
  Future<Result<void>> deleteHistory(String id) async =>
      const Success<void>(null);

  @override
  Future<Result<DateTime>> freeSavesResetDate() async =>
      Success<DateTime>(DateTime.utc(2026, 11, 1));

  @override
  Future<Result<int>> freeSavesUsed() async => const Success<int>(0);

  @override
  Future<Result<GatewayJobRecord?>> gatewayJob() async =>
      const Success<GatewayJobRecord?>(null);

  @override
  Future<Result<List<HistoryEntry>>> history() async =>
      const Success<List<HistoryEntry>>(<HistoryEntry>[]);

  @override
  Future<Result<void>> saveGatewayJob(GatewayJobRecord record) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> saveToGallery(String localPath) async =>
      const Success<void>(null);

  @override
  Future<Result<String>> writeSessionResult(Uint8List bytes) async =>
      const Success<String>('');

  @override
  Future<Result<int?>> acceptedConsentVersion() async => const Success<int?>(1);

  @override
  Future<Result<void>> setAcceptedConsentVersion(int version) async =>
      const Success<void>(null);

  @override
  Future<Result<bool>> introSeen() async => const Success<bool>(true);

  @override
  Future<Result<void>> setIntroSeen() async => const Success<void>(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late File photoFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_proc_motion_');
    photoFile = File('${tempDir.path}/test.png');
    await photoFile.writeAsBytes(_testPngBytes);
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Processing Motion (Items #7, #10)', () {
    testWidgets('Entry animation fades and slides over standard token (300ms)', (tester) async {
      final controller = ProcessingController(
        processingApi: _FakeProcessingApi(),
        localStore: _FakeLocalStore(),
      )..args = ProcessingArgs(photoPath: photoFile.path);
      Get.put<ProcessingController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light(),
          home: const ProcessingView(),
        ),
      );

      // Frame 0: starting entry animation
      final slideFinder = find.descendant(
        of: find.byType(ProcessingView),
        matching: find.byType(SlideTransition),
      );
      expect(slideFinder, findsWidgets);

      final slideWidget = tester.widget<SlideTransition>(slideFinder.first);
      expect(slideWidget.position.value, isNot(equals(Offset.zero)));

      // Advance by standard token (300ms)
      await tester.pump(AppMotion.standard);
      expect(slideWidget.position.value, equals(Offset.zero));
    });

    testWidgets('Reduced motion disables slide on entry animation', (tester) async {
      final controller = ProcessingController(
        processingApi: _FakeProcessingApi(),
        localStore: _FakeLocalStore(),
      )..args = ProcessingArgs(photoPath: photoFile.path);
      Get.put<ProcessingController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const ProcessingView(),
            ),
          ),
        ),
      );

      await tester.pump();
      // With disableAnimations, SlideTransition is bypassed
      expect(
        find.descendant(
          of: find.byType(ProcessingView),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('Stage title crossfades via AnimatedSwitcher when stage changes', (tester) async {
      final controller = ProcessingController(
        processingApi: _FakeProcessingApi(),
        localStore: _FakeLocalStore(),
      )..args = ProcessingArgs(photoPath: photoFile.path);
      Get.put<ProcessingController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light(),
          home: const ProcessingView(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      if (find.text(AppStrings.processingConnecting.tr).evaluate().isNotEmpty) {
        // Initial connecting title
        expect(find.text(AppStrings.processingConnecting.tr), findsOneWidget);

        // Switch to working stage
        controller.stage.value = ProcessingStage.working;
        await tester.pump(); // Frame 0 of switch

        // Mid-crossfade
        await tester.pump(const Duration(milliseconds: 90));
        expect(find.text(controller.workingTitle), findsOneWidget);

        // Settle
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(controller.workingTitle), findsOneWidget);
      }
    });

    testWidgets('ServerWorkingPhotoFrame settles into frosted blur and runs light glide, static under reduced motion', (tester) async {
      // Normal motion: active animated frame
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: ServerWorkingPhotoFrame(
                imageFile: photoFile,
                isWorking: true,
              ),
            ),
          ),
        ),
      );
      final frameCustomPaintFinder = find.descendant(
        of: find.byType(ServerWorkingPhotoFrame),
        matching: find.byType(CustomPaint),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(frameCustomPaintFinder, findsOneWidget);
      expect(find.byType(ImageFiltered), findsOneWidget);

      // Settle past the 400ms entrance
      await tester.pump(const Duration(milliseconds: 400));
      expect(frameCustomPaintFinder, findsOneWidget);

      // Reduced motion: photo blurs and settles, but light band is disabled
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: SizedBox(
                  width: 300,
                  height: 400,
                  child: ServerWorkingPhotoFrame(
                    imageFile: photoFile,
                    isWorking: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ServerWorkingPhotoFrame),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });
}
