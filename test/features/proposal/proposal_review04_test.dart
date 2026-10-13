import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/proposal/model/proposal_args.dart';
import 'package:people_gone/features/proposal/widgets/proposal_photo_canvas.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/storage/local_store.dart';

import '../processing/processing_flow_test.dart' show FakeLocalStore, pngBytes;

/// Review 04 fixes F1–F4: the wired golden path, the repaired canvas,
/// the no-dead-primary states, and the live status sentence.
class ReviewApi implements ProcessingApi {
  Result<DetectionProposal> detectNext = const Failure<DetectionProposal>(
    AppFailure(
      code: 'server',
      userMessageKey: AppStrings.errorProcessingFailed,
    ),
  );
  Result<ProcessedPhoto> processNext = const Failure<ProcessedPhoto>(
    AppFailure(
      code: 'server',
      userMessageKey: AppStrings.errorProcessingFailed,
    ),
  );
  Completer<void>? detectGate;
  int detectCalls = 0;
  int processCalls = 0;
  List<int>? lastKeepIds;

  @override
  Future<Result<DetectionProposal>> detectPersons({
    required String localPath,
    void Function(double fraction)? onUploadProgress,
  }) async {
    detectCalls++;
    if (detectGate != null) await detectGate!.future;
    return detectNext;
  }

  @override
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    void Function(double fraction)? onUploadProgress,
  }) async {
    processCalls++;
    lastKeepIds = keepIds;
    return processNext;
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

class ReviewBinding extends Bindings {
  ReviewBinding(this.api, this.store);
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

DetectionProposal proposalFor(
  String path, {
  required List<DetectedPerson> persons,
}) {
  return DetectionProposal(
    photoPath: path,
    personsDetected: persons.length,
    keeperIds: persons.where((p) => p.isKeeper).map((p) => p.id).toList(),
    removedIds: persons.where((p) => !p.isKeeper).map((p) => p.id).toList(),
    persons: persons,
    inputDimensions: const <int>[639, 360],
  );
}

const twoPeople = <DetectedPerson>[
  DetectedPerson(
    id: 0,
    box: <int>[250, 100, 495, 360],
    score: 0.95,
    isKeeper: true,
  ),
  DetectedPerson(
    id: 1,
    box: <int>[210, 135, 295, 270],
    score: 0.88,
    isKeeper: false,
  ),
];

void main() {
  late Directory tempDir;
  late File picked;
  late ReviewApi api;
  late FakeLocalStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_review04');
    picked = File('${tempDir.path}/picked.png')..writeAsBytesSync(pngBytes);
    api = ReviewApi();
    store = FakeLocalStore(tempDir);
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester) async {
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
  }

  Future<void> openProposal(WidgetTester tester) async {
    Get.toNamed<void>(
      Routes.proposal,
      arguments: ProposalArgs.forPhoto(photoPath: picked.path),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('(i) entering proposal shows Analyzing, calls detectPersons, '
      'then populates chips + status sentence', (tester) async {
    api.detectGate = Completer<void>();
    api.detectNext = Success<DetectionProposal>(
      proposalFor(picked.path, persons: twoPeople),
    );
    await pumpApp(tester);
    await openProposal(tester);
    // Analysing state is on screen while detection is in flight.
    expect(find.text('Analyzing photo…'), findsOneWidget);
    expect(api.detectCalls, 1);
    api.detectGate!.complete();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Analyzing photo…'), findsNothing);
    expect(find.text('Person 1'), findsOneWidget);
    expect(find.text('Person 2'), findsOneWidget);
    expect(
      find.text('1 person will be removed · 1 person protected'),
      findsOneWidget,
    );
  });

  testWidgets(
    '(ii) detect failure falls back to the single-call processing path',
    (tester) async {
      await pumpApp(tester);
      await openProposal(tester);
      await tester.pump(const Duration(milliseconds: 50));
      // Processing ran (its own failure state is what we land on).
      expect(api.processCalls, 1);
      expect(api.lastKeepIds, isNull);
      expect(find.text('Analyzing photo…'), findsNothing);
      expect(
        find.text("We couldn't clean this photo. Please try again."),
        findsOneWidget,
      );
    },
  );

  testWidgets('(iii) confirm passes the KEPT ids into ProcessingArgs', (
    tester,
  ) async {
    api.detectNext = Success<DetectionProposal>(
      proposalFor(
        picked.path,
        persons: const <DetectedPerson>[
          ...twoPeople,
          DetectedPerson(
            id: 2,
            box: <int>[138, 150, 196, 258],
            score: 0.84,
            isKeeper: false,
          ),
        ],
      ),
    );
    await pumpApp(tester);
    await openProposal(tester);
    await tester.pump(const Duration(milliseconds: 50));
    // Protect Person 3 as well, then confirm: keepIds = [0, 2].
    await tester.tap(find.text('Person 3'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Remove 1 person'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.processCalls, 1);
    expect(api.lastKeepIds, <int>[0, 2]);
  });

  testWidgets('(iv) keep-all completes locally: processPhoto NOT called, '
      'Result opens with removedIds empty', (tester) async {
    api.detectNext = Success<DetectionProposal>(
      proposalFor(
        picked.path,
        persons: const <DetectedPerson>[
          DetectedPerson(
            id: 0,
            box: <int>[250, 100, 495, 360],
            score: 0.95,
            isKeeper: true,
          ),
          DetectedPerson(
            id: 1,
            box: <int>[210, 135, 295, 270],
            score: 0.88,
            isKeeper: true,
          ),
        ],
      ),
    );
    await pumpApp(tester);
    await openProposal(tester);
    await tester.pump(const Duration(milliseconds: 50));
    final button = find.text('Keep photo as it is');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.processCalls, 0);
    // Result's nobodyRemoved handling renders the plain message.
    expect(
      find.text("There's nobody in the background to remove."),
      findsOneWidget,
    );
  });

  testWidgets(
    '(v) no-people state: different-photo action is enabled and exits home',
    (tester) async {
      api.detectNext = Success<DetectionProposal>(
        proposalFor(picked.path, persons: const <DetectedPerson>[]),
      );
      await pumpApp(tester);
      await openProposal(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.text("There's nobody in the background to remove."),
        findsOneWidget,
      );
      final button = find.widgetWithText(
        ElevatedButton,
        'Choose a different photo',
      );
      expect(button, findsOneWidget);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
      expect(find.text('Open brush'), findsOneWidget);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('HOME'), findsWidgets);
    },
  );

  test('(vi) painter mapping: pixel box scales into the band', () {
    final rect = scalePersonBoxToBand(
      box: const <int>[272, 91, 520, 359],
      imageSize: const Size(639, 360),
      bandSize: const Size(319.5, 180),
    );
    expect(rect, const Rect.fromLTRB(136, 45.5, 260, 179.5));
    // Overlap rule: the smallest containing box wins the tap.
    final hit = personIdAtBandPoint(
      persons: const <DetectedPerson>[
        DetectedPerson(
          id: 0,
          box: <int>[0, 0, 639, 360],
          score: 0.9,
          isKeeper: true,
        ),
        DetectedPerson(
          id: 1,
          box: <int>[272, 91, 520, 359],
          score: 0.8,
          isKeeper: false,
        ),
      ],
      point: const Offset(200, 100),
      imageSize: const Size(639, 360),
      bandSize: const Size(319.5, 180),
    );
    expect(hit, 1);
  });

  testWidgets('(vii) canvas tap toggles the tapped person', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    int? toggled;
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
                  box: <int>[0, 0, 100, 100],
                  score: 0.95,
                  isKeeper: true,
                ),
                DetectedPerson(
                  id: 1,
                  box: <int>[40, 40, 60, 60],
                  score: 0.88,
                  isKeeper: false,
                ),
              ],
              imageSize: const Size(100, 100),
              onTogglePerson: (id) => toggled = id,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final origin = tester.getTopLeft(find.byType(ProposalPhotoCanvas));
    // Centre lands in both boxes; the smallest (Person 2) wins.
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    expect(toggled, 1);
    // A corner point is only inside Person 1's box.
    await tester.tapAt(origin + const Offset(20, 20));
    await tester.pump();
    expect(toggled, 0);
    // TalkBack semantics per person (direction R2): the painter's
    // custom semantics nodes carry one labelled element per person.
    final labels = <String>[];
    bool collect(SemanticsNode node) {
      final label = node.getSemanticsData().label;
      if (label.isNotEmpty) labels.add(label);
      node.visitChildren(collect);
      return true;
    }

    collect(
      tester.getSemantics(
        find.descendant(
          of: find.byType(ProposalPhotoCanvas),
          matching: find.byType(CustomPaint),
        ),
      ),
    );
    expect(labels, contains('Person 2, marked to remove. Double-tap to keep.'));
    expect(labels, contains('Person 1, protected. Double-tap to remove.'));
    semanticsHandle.dispose();
  });

  testWidgets('(viii) status sentence updates on every toggle', (tester) async {
    api.detectNext = Success<DetectionProposal>(
      proposalFor(picked.path, persons: twoPeople),
    );
    await pumpApp(tester);
    await openProposal(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text('1 person will be removed · 1 person protected'),
      findsOneWidget,
    );
    await tester.tap(find.text('Person 1'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text('2 people will be removed · 0 people protected'),
      findsOneWidget,
    );
    await tester.tap(find.text('Person 1'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text('1 person will be removed · 1 person protected'),
      findsOneWidget,
    );
  });
}
