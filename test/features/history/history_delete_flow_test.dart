import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/history/controller/history_controller.dart';
import 'package:people_gone/features/history/view/history_detail_view.dart';
import 'package:people_gone/features/history/view/history_view.dart';
import 'package:people_gone/services/storage/local_store.dart';

class _FakeStore implements LocalStore {
  final List<HistoryEntry> items = <HistoryEntry>[
    HistoryEntry(
      id: 'h1',
      localPath: '/tmp/test_h1.jpg',
      savedAt: DateTime(2026, 10, 1),
    ),
    HistoryEntry(
      id: 'h2',
      localPath: '/tmp/test_h2.jpg',
      savedAt: DateTime(2026, 10, 2),
    ),
  ];

  @override
  Future<Result<List<HistoryEntry>>> history() async =>
      Success<List<HistoryEntry>>(List<HistoryEntry>.from(items));

  @override
  Future<Result<void>> deleteHistory(String id) async {
    items.removeWhere((e) => e.id == id);
    return const Success<void>(null);
  }

  @override
  Future<Result<bool>> introSeen() async => const Success<bool>(true);

  @override
  Future<Result<void>> setIntroSeen() async => const Success<void>(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'Delete from History detail pops route immediately back to History and entry is removed (no manual back needed)',
    (tester) async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(780, 1688);
      addTearDown(tester.view.reset);

      final store = _FakeStore();
      Get.put<LocalStore>(store);
      final historyController = HistoryController(localStore: store);
      Get.put<HistoryController>(historyController);

      await tester.pumpWidget(
        GetMaterialApp(
          debugShowCheckedModeBanner: false,
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          theme: AppTheme.light(),
          initialRoute: Routes.history,
          getPages: AppPages.pages,
        ),
      );
      await tester.pumpAndSettle();

      // We should see both items in the history view
      expect(find.byType(HistoryView), findsOneWidget);
      expect(historyController.entries.length, 2);

      // Tap first item to open detail
      await tester.tap(find.text('Oct 1, 2026'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryDetailView), findsOneWidget);

      final deleteBtn = find.text('Delete');
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Delete this photo from history?'), findsOneWidget);

      // Tap Delete in dialog
      final confirmBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Delete'),
      );
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      // The detail screen MUST be gone immediately without manual back
      expect(find.byType(HistoryDetailView), findsNothing);
      expect(find.byType(HistoryView), findsOneWidget);

      // Settle the delete animation (250ms)
      await tester.pump(const Duration(milliseconds: 200));

      // Settled history list: deleted item is removed, and snackbar confirmation is visible
      expect(historyController.entries.any((e) => e.id == 'h1'), isFalse);
      expect(historyController.entries.length, 1);
      expect(historyController.entries.first.id, 'h2');
      expect(find.text('Removed from history'), findsOneWidget);

      // Drain snackbar timer and its exit animation
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );
}
