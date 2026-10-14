import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/processing/model/processing_args.dart';
import 'package:people_gone/features/proposal/controller/proposal_controller.dart';
import 'package:people_gone/features/proposal/model/proposal_args.dart';
import 'package:people_gone/features/proposal/widgets/item_card.dart';
import 'package:people_gone/features/proposal/widgets/proposal_photo_canvas.dart';
import 'package:people_gone/services/processing/processing_api.dart';

import '../processing/processing_flow_test.dart' show FakeLocalStore, pngBytes;
import '../result/result_flow_test.dart' show FakeProcessingApi;
import 'proposal_review04_test.dart' show ReviewApi, ReviewBinding;

/// Phase A belongings on S4 (FR-08; design X8-X11): the Includes
/// line + detach/re-attach, the Distractions group shell for
/// ambiguous items (default Keep), the confirm payload, and the
/// keep-all-people + included-item state staying a real server job.
void main() {
  late Directory tempDir;
  late File picked;
  late ReviewApi api;
  late FakeLocalStore store;

  const persons = <DetectedPerson>[
    DetectedPerson(
      id: 0,
      box: <int>[60, 60, 200, 300],
      score: 0.97,
      isKeeper: true,
    ),
    DetectedPerson(
      id: 1,
      box: <int>[300, 60, 440, 300],
      score: 0.93,
      isKeeper: false,
    ),
  ];

  const belongings = <DetectedBelonging>[
    DetectedBelonging(
      id: 0,
      detectedClass: 'handbag',
      box: <int>[400, 150, 450, 220],
      score: 0.81,
      tier: BelongingTier.attached,
      personId: 1,
    ),
    DetectedBelonging(
      id: 1,
      detectedClass: 'suitcase',
      box: <int>[480, 200, 560, 300],
      score: 0.66,
      tier: BelongingTier.ambiguous,
    ),
  ];

  DetectionProposal v3Proposal() => DetectionProposal(
        photoPath: picked.path,
        personsDetected: 2,
        keeperIds: const <int>[0],
        removedIds: const <int>[1],
        persons: persons,
        belongings: belongings,
        inputDimensions: const <int>[640, 360],
      );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_belongings');
    picked = File('${tempDir.path}/picked.png')..writeAsBytesSync(pngBytes);
    api = ReviewApi();
    store = FakeLocalStore(tempDir);
    api.detectNext = Success<DetectionProposal>(v3Proposal());
    api.processNext = Success<ProcessedPhoto>(
      ProcessedPhoto(
        resultBytes: pngBytes,
        personsDetected: 2,
        keeperIds: const <int>[0],
        removedIds: const <int>[1],
        totalSeconds: 3.5,
        engineUsed: 'mat',
        cropsInpainted: 1,
        persons: persons,
        itemsRemoved: 1,
      ),
    );
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> openProposal(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        initialBinding: ReviewBinding(api, store),
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
      Routes.proposal,
      arguments: ProposalArgs.forPhoto(photoPath: picked.path),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets(
    'renders Includes line for the owner and the Distractions group '
    'with the ambiguous item defaulting to Keep',
    (tester) async {
      await openProposal(tester);

      expect(find.text('Includes:'), findsOneWidget);
      expect(find.text('Handbag'), findsOneWidget);
      expect(find.text('Distractions'), findsOneWidget);
      expect(find.text('Suitcase'), findsOneWidget);
      expect(find.text('Keep'), findsOneWidget);
      // Nothing included yet: no items clause, people-only label.
      expect(
        find.text('1 person will be removed · 1 person protected'),
        findsOneWidget,
      );
      expect(find.text('Remove 1 person'), findsOneWidget);
    },
  );

  testWidgets('detach protects the belonging; re-attach restores it; '
      'the confirm payload carries the detached id', (tester) async {
    await openProposal(tester);
    final controller = Get.find<ProposalController>();

    await tester.tap(find.text('Handbag'));
    await tester.pump();
    expect(controller.detachedBelongingIds, <int>{0});
    expect(controller.isDetached(0), isTrue);

    await tester.tap(find.text('Handbag'));
    await tester.pump();
    expect(controller.detachedBelongingIds, isEmpty);

    // Detach again and confirm: the payload must carry it.
    await tester.tap(find.text('Handbag'));
    await tester.pump();
    await tester.tap(find.text('Remove 1 person'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.processCalls, 1);
    expect(api.lastKeepIds, <int>[0]);
    expect(api.lastDetachedBelongingIds, <int>[0]);
    expect(api.lastRemoveItemIds, <int>[]);
  });

  testWidgets('including an ambiguous item extends the status sentence '
      'and the confirm label, and lands in the payload', (tester) async {
    await openProposal(tester);
    final controller = Get.find<ProposalController>();

    await tester.tap(find.text('Suitcase'));
    await tester.pump();
    expect(controller.includedItemIds, <int>{1});
    expect(
      find.text(
        '1 person will be removed · 1 item will be removed · '
        '1 person protected',
      ),
      findsOneWidget,
    );
    expect(find.text('Remove 1 person + 1 item'), findsOneWidget);
    // The item's pill flipped to Remove (the person pill also reads
    // "Remove", so scope the finder to the item card).
    expect(
      find.descendant(
        of: find.byType(ItemCard),
        matching: find.text('Remove'),
      ),
      findsOneWidget,
    );

    // Excluding returns to the people-only state.
    await tester.tap(find.text('Suitcase'));
    await tester.pump();
    expect(controller.includedItemIds, isEmpty);
    expect(find.text('Remove 1 person'), findsOneWidget);

    // Include once more and confirm.
    await tester.tap(find.text('Suitcase'));
    await tester.pump();
    await tester.tap(find.text('Remove 1 person + 1 item'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.processCalls, 1);
    expect(api.lastRemoveItemIds, <int>[1]);
    expect(api.lastDetachedBelongingIds, <int>[]);
  });

  testWidgets('keep-all people + an included item is a server job '
      'labelled with the item, never the local keep-all', (tester) async {
    await openProposal(tester);

    // Keep Person 2 as well: nobody is being removed now.
    await tester.tap(find.text('Person 2'));
    await tester.pump();
    expect(find.text('Keep photo as it is'), findsOneWidget);

    await tester.tap(find.text('Suitcase'));
    await tester.pump();
    // The primary becomes the item job, not the local completion.
    expect(find.text('Keep photo as it is'), findsNothing);
    expect(find.text('Remove 1 item'), findsOneWidget);

    await tester.tap(find.text('Remove 1 item'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.processCalls, 1);
    expect(api.lastKeepIds, <int>[0, 1]);
    expect(api.lastRemoveItemIds, <int>[1]);
  });

  testWidgets('result summary counts the included item (X16)',
      (tester) async {
    final resultApi = FakeProcessingApi();
    final outcome = ProcessingOutcome(
      originalPath: picked.path,
      resultPath: picked.path,
      personsDetected: 2,
      keeperIds: const <int>[0],
      removedIds: const <int>[1],
      totalSeconds: 3.5,
      engineUsed: 'mat',
      itemsRemoved: 1,
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        initialBinding: ReviewBinding(resultApi, store),
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
    Get.toNamed<void>(Routes.result, arguments: outcome);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text(
        '1 of 2 people and 1 item removed. '
        'Your subject stays untouched.',
      ),
      findsOneWidget,
    );
  });

  group('canvas hit-testing (belongings)', () {
    const imageSize = Size(640, 360);
    const bandSize = Size(640, 360);

    test('smallest containing box wins among items', () {
      const items = <DetectedBelonging>[
        DetectedBelonging(
          id: 0,
          detectedClass: 'suitcase',
          box: <int>[100, 100, 300, 300],
          score: 0.9,
          tier: BelongingTier.ambiguous,
        ),
        DetectedBelonging(
          id: 1,
          detectedClass: 'handbag',
          box: <int>[150, 150, 220, 220],
          score: 0.8,
          tier: BelongingTier.ambiguous,
        ),
      ];
      expect(
        belongingIdAtBandPoint(
          items: items,
          point: const Offset(180, 180),
          imageSize: imageSize,
          bandSize: bandSize,
        ),
        1,
      );
      expect(
        belongingIdAtBandPoint(
          items: items,
          point: const Offset(120, 120),
          imageSize: imageSize,
          bandSize: bandSize,
        ),
        0,
      );
      expect(
        belongingIdAtBandPoint(
          items: items,
          point: const Offset(500, 50),
          imageSize: imageSize,
          bandSize: bandSize,
        ),
        isNull,
      );
    });
  });
}
