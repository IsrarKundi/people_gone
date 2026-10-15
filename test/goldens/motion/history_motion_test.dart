import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/history/controller/history_controller.dart';
import 'package:people_gone/features/history/view/history_view.dart';
import 'package:people_gone/features/history/widgets/history_grid.dart';
import 'package:people_gone/services/storage/local_store.dart';

final Uint8List _testPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class _MockLocalStore implements LocalStore {
  _MockLocalStore(this.items);
  List<HistoryEntry> items;

  @override
  Future<Result<int>> freeSavesUsed() async => const Success<int>(0);

  @override
  Future<Result<DateTime>> freeSavesResetDate() async =>
      Success<DateTime>(DateTime.now());

  @override
  Future<Result<void>> consumeFreeSave() async => const Success<void>(null);

  @override
  Future<Result<void>> saveToGallery(String localPath) async =>
      const Success<void>(null);

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
      Success<List<HistoryEntry>>(items);

  @override
  Future<Result<void>> deleteHistory(String id) async {
    items.removeWhere((e) => e.id == id);
    return const Success<void>(null);
  }

  @override
  Future<Result<String>> writeSessionResult(List<int> bytes) async =>
      const Success<String>('/session/res.jpg');

  @override
  Future<Result<int?>> acceptedConsentVersion() async => const Success<int?>(1);

  @override
  Future<Result<void>> setAcceptedConsentVersion(int version) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearGatewayJob() async => const Success<void>(null);

  @override
  Future<Result<GatewayJobRecord?>> gatewayJob() async =>
      const Success<GatewayJobRecord?>(null);

  @override
  Future<Result<void>> saveGatewayJob(GatewayJobRecord record) async =>
      const Success<void>(null);
}

void main() {
  late Directory tempDir;
  late File photo1;
  late File photo2;
  late File photo3;
  late _MockLocalStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pg_history_motion_');
    photo1 = File('${tempDir.path}/p1.png')..writeAsBytesSync(_testPngBytes);
    photo2 = File('${tempDir.path}/p2.png')..writeAsBytesSync(_testPngBytes);
    photo3 = File('${tempDir.path}/p3.png')..writeAsBytesSync(_testPngBytes);
    store = _MockLocalStore(<HistoryEntry>[
      HistoryEntry(
        id: '1',
        localPath: photo1.path,
        savedAt: DateTime(2026, 10, 1),
      ),
      HistoryEntry(
        id: '2',
        localPath: photo2.path,
        savedAt: DateTime(2026, 10, 2),
      ),
      HistoryEntry(
        id: '3',
        localPath: photo3.path,
        savedAt: DateTime(2026, 10, 3),
      ),
    ]);
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
    Get.reset();
  });

  testWidgets('Item 17: History tile has Hero flight support with display-resolution copies',
      (tester) async {
    Get.put<LocalStore>(store);
    final controller = HistoryController(localStore: store);
    Get.put<HistoryController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        home: const HistoryView(),
      ),
    );
    await tester.pump();

    // Verify Heroes exist for entries in the grid
    final heroFinder = find.byType(Hero);
    expect(heroFinder, findsWidgets);

    final firstHero = tester.widget<Hero>(heroFinder.first);
    expect(firstHero.tag, 'history_photo_1');
    expect(firstHero.flightShuttleBuilder, isNotNull);
  });

  testWidgets('Item 18: Delete animates tile fading + scaling out and closes grid gap over 250ms',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HistoryGrid(
            entries: store.items,
            deletingId: null,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Initial state: 3 items in grid
    expect(find.text('Oct 2, 2026'), findsOneWidget);

    // Trigger delete on item '2' (middle tile)
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HistoryGrid(
            entries: store.items,
            deletingId: '2',
            onTap: (_) {},
          ),
        ),
      ),
    );

    // Frame strip 0: t=0ms (delete starts)
    await tester.pump();
    await expectLater(
      find.byType(HistoryGrid),
      matchesGoldenFile('history_delete_frame0.png'),
    );

    // Frame strip 1: t=125ms (halfway: tile 2 half scaled/faded, tile 3 translating toward gap)
    await tester.pump(const Duration(milliseconds: 125));
    await expectLater(
      find.byType(HistoryGrid),
      matchesGoldenFile('history_delete_frame1.png'),
    );

    // Frame strip 2: t=250ms (delete complete: tile 2 gone, tile 3 at gap)
    await tester.pump(const Duration(milliseconds: 125));
    await expectLater(
      find.byType(HistoryGrid),
      matchesGoldenFile('history_delete_frame2.png'),
    );
  });

  testWidgets('Reduced motion disables Hero spatial tag and skips delete transition',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(
              body: HistoryGrid(
                entries: store.items,
                deletingId: '2',
                onTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Under reduced motion, no Hero tags created for spatial flight
    final heroes = find.byType(Hero);
    expect(heroes, findsNothing);
  });
}
