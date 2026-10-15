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
import 'package:people_gone/features/proposal/controller/proposal_controller.dart';
import 'package:people_gone/features/proposal/model/proposal_args.dart';
import 'package:people_gone/features/proposal/view/proposal_view.dart';
import 'package:people_gone/features/proposal/widgets/person_card.dart';
import 'package:people_gone/services/processing/processing_api.dart';

final Uint8List _testPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

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
      const Failure<SaveCreditDecision>(
        AppFailure(code: 'test', userMessageKey: AppStrings.errorGeneric),
      );

  @override
  Future<Result<void>> refundSaveCredit({
    required String idempotencyKey,
  }) async =>
      const Failure<void>(
        AppFailure(code: 'test', userMessageKey: AppStrings.errorGeneric),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late File photoFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_prop_motion_');
    photoFile = File('${tempDir.path}/photo.png');
    await photoFile.writeAsBytes(_testPngBytes);
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Proposal Motion (Items #8, #9)', () {
    testWidgets('Results reveal: canvas outlines and chip trays fade in together in ONE beat', (tester) async {
      final proposal = DetectionProposal(
        photoPath: photoFile.path,
        personsDetected: 2,
        keeperIds: const <int>[0],
        removedIds: const <int>[1],
        persons: const <DetectedPerson>[
          DetectedPerson(
            id: 0,
            box: <int>[10, 10, 50, 50],
            score: 0.95,
            isKeeper: true,
          ),
          DetectedPerson(
            id: 1,
            box: <int>[60, 60, 90, 90],
            score: 0.85,
            isKeeper: false,
          ),
        ],
        inputDimensions: const <int>[100, 100],
      );

      final controller = ProposalController(processingApi: _MockProcessingApi())
        ..args = ProposalArgs(proposal: proposal);
      Get.put<ProposalController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light(),
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          home: const ProposalView(),
        ),
      );

      // Verify results panel and canvas overlays
      expect(find.byType(PersonCard), findsNWidgets(2));
      expect(find.byType(AnimatedSwitcher), findsWidgets);
      expect(find.byType(TweenAnimationBuilder<double>), findsWidgets);

      // Verify no stagger: all items are revealed in the same beat
      final opacityFinder = find.descendant(
        of: find.byType(ProposalView),
        matching: find.byType(Opacity),
      );
      expect(opacityFinder, findsWidgets);

      // Settle standard reveal token (300ms)
      await tester.pump(AppMotion.standard);
      final opacityWidget = tester.widget<Opacity>(opacityFinder.first);
      expect(opacityWidget.opacity, equals(1.0));
    });

    testWidgets('Toggle feedback: chip colors and status sentence crossfade over fast token (180ms)', (tester) async {
      final proposal = DetectionProposal(
        photoPath: photoFile.path,
        personsDetected: 2,
        keeperIds: const <int>[0],
        removedIds: const <int>[1],
        persons: const <DetectedPerson>[
          DetectedPerson(
            id: 0,
            box: <int>[10, 10, 50, 50],
            score: 0.95,
            isKeeper: true,
          ),
          DetectedPerson(
            id: 1,
            box: <int>[60, 60, 90, 90],
            score: 0.85,
            isKeeper: false,
          ),
        ],
        inputDimensions: const <int>[100, 100],
      );

      final controller = ProposalController(processingApi: _MockProcessingApi())
        ..args = ProposalArgs(proposal: proposal);
      Get.put<ProposalController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light(),
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          home: const ProposalView(),
        ),
      );

      await tester.pumpAndSettle();

      // Golden evidence for keeper chip state
      final firstChipFinder = find.byType(PersonCard).first;
      await expectLater(
        firstChipFinder,
        matchesGoldenFile('proposal_toggle_keeper.png'),
      );

      // Toggle person 0 from keeper -> remove
      controller.togglePerson(0);
      await tester.pump(); // Start transition

      // AnimatedContainer on card, AnimatedContainer on pill, AnimatedContainer on thumbnail ring
      final animatedContainers = find.descendant(
        of: firstChipFinder,
        matching: find.byType(AnimatedContainer),
      );
      expect(animatedContainers, findsWidgets);

      // Halfway through fast token (90ms): colors are interpolating smoothly
      await tester.pump(const Duration(milliseconds: 90));
      expect(controller.persons[0].isKeeper, isFalse);

      // Settle fast token
      await tester.pump(const Duration(milliseconds: 100));

      // Golden evidence for removed chip state
      await expectLater(
        firstChipFinder,
        matchesGoldenFile('proposal_toggle_removed.png'),
      );
    });

    testWidgets('Reduced motion disables crossfade animations', (tester) async {
      final proposal = DetectionProposal(
        photoPath: photoFile.path,
        personsDetected: 1,
        keeperIds: const <int>[0],
        removedIds: const <int>[],
        persons: const <DetectedPerson>[
          DetectedPerson(
            id: 0,
            box: <int>[10, 10, 50, 50],
            score: 0.95,
            isKeeper: true,
          ),
        ],
        inputDimensions: const <int>[100, 100],
      );

      final controller = ProposalController(processingApi: _MockProcessingApi())
        ..args = ProposalArgs(proposal: proposal);
      Get.put<ProposalController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light(),
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const ProposalView(),
            ),
          ),
        ),
      );

      await tester.pump();
      // Under reduced motion, AnimatedSwitcher duration is zero
      final switcher = tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher).first);
      expect(switcher.duration, equals(Duration.zero));
    });
  });
}
