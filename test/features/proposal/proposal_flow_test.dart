import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/features/proposal/controller/proposal_controller.dart';
import 'package:people_gone/features/proposal/model/proposal_args.dart';
import 'package:people_gone/services/processing/processing_api.dart';

import '../processing/processing_flow_test.dart' show FakeProcessingApi;

final Uint8List pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  late Directory tempDir;
  late File photoFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('proposal_test_');
    photoFile = File('${tempDir.path}/test_photo.jpg');
    await photoFile.writeAsBytes(pngBytes);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
    Get.reset();
  });

  Widget buildApp(DetectionProposal proposal) {
    return GetMaterialApp(
      theme: AppTheme.light(),
      initialRoute: Routes.proposal,
      getPages: AppPages.pages,
      translations: AppTranslations(),
      locale: const Locale('en'),
      onGenerateRoute: (settings) {
        if (settings.name == Routes.proposal) {
          Get.parameters = <String, String>{};
        }
        return null;
      },
      onInit: () {
        Get.put<ProposalController>(
          ProposalController(processingApi: FakeProcessingApi()),
        );
      },
    );
  }

  testWidgets(
    'ProposalView shows detected people, toggles live count, and warns on overlap',
    (tester) async {
      // Subject (keeper) box: [100, 100, 300, 500]
      // Overlapping background removal box: [250, 200, 400, 450]
      final proposal = DetectionProposal(
        photoPath: photoFile.path,
        personsDetected: 2,
        keeperIds: const <int>[0],
        removedIds: const <int>[1],
        persons: const <DetectedPerson>[
          DetectedPerson(
            id: 0,
            box: <int>[100, 100, 300, 500],
            score: 0.95,
            isKeeper: true,
          ),
          DetectedPerson(
            id: 1,
            box: <int>[250, 200, 400, 450],
            score: 0.85,
            isKeeper: false,
          ),
        ],
        inputDimensions: const <int>[1000, 1000],
      );

      // Seed arguments
      Get.testMode = true;
      Get.routing.args = ProposalArgs(proposal: proposal);

      await tester.pumpWidget(buildApp(proposal));
      await tester.pumpAndSettle();

      // 1. Title and overlap warning rendered
      expect(find.text(AppStrings.proposalTitle.tr), findsOneWidget);
      expect(find.text(AppStrings.proposalOverlapWarning.tr), findsOneWidget);

      // 2. Initial count button: "Remove 1 person"
      expect(find.text(AppStrings.proposalRemoveOne.tr), findsOneWidget);

      // 3. Person cards exist
      expect(find.text('Person 1'), findsOneWidget);
      expect(find.text('Person 2'), findsOneWidget);

      // 4. Tap Person 1 to toggle it from keeper to remove
      await tester.tap(find.text('Person 1'));
      await tester.pumpAndSettle();

      // Now both are marked for removal -> "Remove 2 people"
      expect(find.text('Remove 2 people'), findsOneWidget);

      // 5. Tap Person 1 again to toggle back to keeper
      await tester.tap(find.text('Person 1'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.proposalRemoveOne.tr), findsOneWidget);

      // 6. Tap Person 2 to toggle to keeper -> 0 removals -> keep-all
      // completes locally (Review 04 F3): the button says what happens.
      await tester.tap(find.text('Person 2'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.proposalKeepAllAction.tr), findsOneWidget);
    },
  );
}
