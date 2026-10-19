import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/processing/controller/processing_controller.dart';
import 'package:people_gone/features/proposal/controller/proposal_controller.dart';
import 'package:people_gone/features/proposal/model/distraction_label.dart';
import 'package:people_gone/features/proposal/model/proposal_args.dart';
import 'package:people_gone/features/proposal/widgets/distraction_card.dart';
import 'package:people_gone/features/proposal/widgets/proposal_photo_canvas.dart';
import 'package:people_gone/services/processing/gateway_parsing.dart';
import 'package:people_gone/services/processing/processing_api.dart';

import '../processing/processing_flow_test.dart' show FakeLocalStore, pngBytes;
import 'proposal_review04_test.dart' show ReviewApi, ReviewBinding;

/// Phase B distractions on S4 (design X1-X7, X15, X16): the group
/// carries real distractions beside ambiguous belongings, defaults
/// Keep, the header sets the whole group, the confirm payload
/// carries distraction ids, S6 names the job's distractions, and
/// S7 names them in the summary.
class GatedReviewApi extends ReviewApi {
  /// Assigned by the test that needs to hold the job in flight —
  /// created inside the test body so its completion is scheduled in
  /// the test's fake-async zone (a setUp-created completer's release
  /// only drained at teardown).
  Completer<void> processGate = Completer<void>();

  @override
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    List<int>? removeItemIds,
    List<int>? detachedBelongingIds,
    void Function(double fraction)? onUploadProgress,
  }) async {
    // Record at ENTRY (like ReviewApi) — the gate holds the RESULT,
    // not the call, so payload assertions work while S6 is on screen.
    processCalls++;
    lastKeepIds = keepIds;
    lastRemoveItemIds = removeItemIds;
    lastDetachedBelongingIds = detachedBelongingIds;
    onUploadProgress?.call(1.0);
    await processGate.future;
    return processNext;
  }
}

void main() {
  late Directory tempDir;
  late File picked;
  late GatedReviewApi api;
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
      id: 1,
      detectedClass: 'suitcase',
      box: <int>[480, 200, 560, 300],
      score: 0.66,
      tier: BelongingTier.ambiguous,
    ),
  ];

  const distractions = <DetectedDistraction>[
    DetectedDistraction(
      id: 10000,
      category: 'car',
      box: <int>[460, 40, 600, 140],
      score: 0.93,
    ),
    DetectedDistraction(
      id: 10001,
      category: 'trash bin',
      box: <int>[20, 300, 90, 355],
      score: 0.85,
    ),
  ];

  DetectionProposal proposal() => DetectionProposal(
    photoPath: picked.path,
    personsDetected: 2,
    keeperIds: const <int>[0],
    removedIds: const <int>[1],
    persons: persons,
    belongings: belongings,
    distractions: distractions,
    inputDimensions: const <int>[640, 360],
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_distractions');
    picked = File('${tempDir.path}/picked.png')..writeAsBytesSync(pngBytes);
    api = GatedReviewApi();
    store = FakeLocalStore(tempDir);
    api.detectNext = Success<DetectionProposal>(proposal());
    api.processNext = Success<ProcessedPhoto>(
      ProcessedPhoto(
        resultBytes: pngBytes,
        personsDetected: 2,
        keeperIds: const <int>[0],
        removedIds: const <int>[1],
        totalSeconds: 3.5,
        engineUsed: 'mat',
        cropsInpainted: 2,
        persons: persons,
        distractionsRemoved: 1,
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

  testWidgets('group renders distractions + ambiguous belongings, all default '
      'Keep, with Remove all / Keep all in the header', (tester) async {
    await openProposal(tester);

    expect(find.text('Distractions'), findsOneWidget);
    expect(find.text('Remove all'), findsOneWidget);
    expect(find.text('Keep all'), findsOneWidget);
    expect(find.text('Suitcase'), findsOneWidget);
    expect(find.text('Car'), findsOneWidget);
    expect(find.text('Trash bin'), findsOneWidget);
    expect(find.byType(DistractionCard), findsNWidgets(2));
    // Every chip defaults to Keep (X3): three Keep pills in the group.
    expect(
      find.descendant(
        of: find.byType(DistractionCard),
        matching: find.text('Keep'),
      ),
      findsNWidgets(2),
    );
    final controller = Get.find<ProposalController>();
    expect(controller.includedCount, 0);
    expect(controller.hasRemovals, isTrue); // person 1 is a removal
  });

  testWidgets(
    'Remove all sets the WHOLE group (both kinds); Keep all clears it',
    (tester) async {
      await openProposal(tester);
      final controller = Get.find<ProposalController>();

      await tester.tap(find.text('Remove all'));
      await tester.pump();
      expect(controller.includedItemIds, <int>{1});
      expect(controller.includedDistractionIds, <int>{10000, 10001});
      expect(
        find.text(
          '1 person will be removed · 3 items will be removed · '
          '1 person protected',
        ),
        findsOneWidget,
      );
      expect(find.text('Remove 1 person + 3 items'), findsOneWidget);

      await tester.tap(find.text('Keep all'));
      await tester.pump();
      expect(controller.includedItemIds, isEmpty);
      expect(controller.includedDistractionIds, isEmpty);
      expect(find.text('Remove 1 person'), findsOneWidget);
    },
  );

  testWidgets('tapping a distraction chip includes it; the confirm payload '
      'carries its id in remove_item_ids', (tester) async {
    await openProposal(tester);
    final controller = Get.find<ProposalController>();

    await tester.tap(find.text('Car'));
    await tester.pump();
    expect(controller.includedDistractionIds, <int>{10000});
    expect(find.text('Remove 1 person + 1 item'), findsOneWidget);

    await tester.tap(find.text('Remove 1 person + 1 item'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.processCalls, 1);
    expect(api.lastKeepIds, <int>[0]);
    expect(api.lastRemoveItemIds, <int>[10000]);
    api.processGate.complete();
  });

  testWidgets('keep-all-people + an included distraction is a REAL server job '
      '(never the local keep-all completion)', (tester) async {
    await openProposal(tester);
    final controller = Get.find<ProposalController>();

    controller.togglePerson(1); // keep everyone
    await tester.pump();
    expect(controller.removeCount, 0);

    await tester.tap(find.text('Trash bin'));
    await tester.pump();
    expect(controller.hasRemovals, isTrue);
    expect(find.text('Remove 1 item'), findsOneWidget);

    await tester.tap(find.text('Remove 1 item'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.processCalls, 1);
    expect(api.lastKeepIds, <int>[0, 1]);
    expect(api.lastRemoveItemIds, <int>[10001]);
    api.processGate.complete();
  });

  testWidgets(
    'S6 names the job (X15) and S7 names the removed distraction (X16)',
    (tester) async {
      api.processGate = Completer<void>();
      await openProposal(tester);

      await tester.tap(find.text('Car'));
      await tester.pump();
      await tester.tap(find.text('Remove 1 person + 1 item'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The job is gated mid-flight: S6 derives the working title.
      expect(
        Get.find<ProcessingController>().workingTitle,
        'Removing 1 person and 1 distraction…',
      );

      api.processGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.text(
          '1 of 2 people and 1 distraction removed. '
          'Your subject stays untouched.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('canvas tap priority: a distraction under a person loses to the '
      'person; a distraction-only point toggles the distraction', (
    tester,
  ) async {
    int? toggledPerson;
    int? toggledDistraction;
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: ProposalPhotoCanvas(
              photoPath: picked.path,
              persons: const <DetectedPerson>[
                DetectedPerson(
                  id: 0,
                  box: <int>[0, 0, 60, 60],
                  score: 0.95,
                  isKeeper: true,
                ),
              ],
              imageSize: const Size(100, 100),
              onTogglePerson: (id) => toggledPerson = id,
              distractions: const <DetectedDistraction>[
                DetectedDistraction(
                  id: 10000,
                  category: 'car',
                  box: <int>[30, 30, 100, 100],
                  score: 0.9,
                ),
              ],
              onToggleDistraction: (id) => toggledDistraction = id,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final origin = tester.getTopLeft(find.byType(ProposalPhotoCanvas));

    // (90,90) in canvas px = (45,45) in image px: inside BOTH the
    // person box (0-60) and the car box (30-100). Person wins (X7).
    await tester.tapAt(origin + const Offset(90, 90));
    await tester.pump();
    expect(toggledPerson, 0);
    expect(toggledDistraction, isNull);

    // (170,170) canvas = (85,85) image: inside the car only.
    await tester.tapAt(origin + const Offset(170, 170));
    await tester.pump();
    expect(toggledDistraction, 10000);
  });

  group('pure helpers', () {
    test('category labels map every shipped category + Item fallback', () {
      const expected = <String, String>{
        'car': AppStrings.distractionClassCar,
        'bus': AppStrings.distractionClassBus,
        'truck': AppStrings.distractionClassTruck,
        'motorbike': AppStrings.distractionClassMotorbike,
        'bicycle': AppStrings.distractionClassBicycle,
        'traffic light': AppStrings.distractionClassTrafficLight,
        'parking meter': AppStrings.distractionClassParkingMeter,
        'bench': AppStrings.distractionClassBench,
        'fire hydrant': AppStrings.distractionClassFireHydrant,
        'trash bin': AppStrings.distractionClassTrashBin,
        'stroller': AppStrings.distractionClassStroller,
      };
      for (final entry in expected.entries) {
        expect(
          distractionCategoryLabelKey(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
      expect(
        distractionCategoryLabelKey('helicopter'),
        AppStrings.belongingClassOther,
      );
      expect(distractionCategoryLabelKey(''), AppStrings.belongingClassOther);
    });

    test('gatewayParseDistractions skips malformed entries', () {
      final parsed = gatewayParseDistractions(<dynamic>[
        <String, dynamic>{
          'id': 10000,
          'kind': 'distraction',
          'category': 'car',
          'box': <int>[1, 2, 3, 4],
          'score': 0.9,
        },
        <String, dynamic>{
          'id': 10001,
          'category': 'bench',
          'box': <int>[1, 2, 3], // malformed: no full box
          'score': 0.8,
        },
        'not a map',
        <String, dynamic>{
          'id': 10002,
          'category': 'stroller',
          'box': <int>[5, 6, 7, 8],
        },
      ]);
      expect(parsed.length, 2);
      expect(parsed[0].category, 'car');
      expect(parsed[0].id, 10000);
      expect(parsed[1].category, 'stroller');
      expect(parsed[1].score, 1.0); // missing score defaults
      expect(gatewayParseDistractions(null), isEmpty);
      expect(gatewayParseDistractions('junk'), isEmpty);
    });

    test('distractionIdAtBandPoint: smallest containing box wins', () {
      const items = <DetectedDistraction>[
        DetectedDistraction(
          id: 10000,
          category: 'car',
          box: <int>[0, 0, 100, 100],
          score: 0.9,
        ),
        DetectedDistraction(
          id: 10001,
          category: 'bench',
          box: <int>[40, 40, 60, 60],
          score: 0.8,
        ),
      ];
      expect(
        distractionIdAtBandPoint(
          distractions: items,
          point: const Offset(50, 50),
          imageSize: const Size(100, 100),
          bandSize: const Size(100, 100),
        ),
        10001,
      );
      expect(
        distractionIdAtBandPoint(
          distractions: items,
          point: const Offset(10, 10),
          imageSize: const Size(100, 100),
          bandSize: const Size(100, 100),
        ),
        10000,
      );
      expect(
        distractionIdAtBandPoint(
          distractions: items,
          point: const Offset(150, 150),
          imageSize: const Size(100, 100),
          bandSize: const Size(100, 100),
        ),
        isNull,
      );
    });
  });
}
