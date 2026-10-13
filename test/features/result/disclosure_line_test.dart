import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/features/result/widgets/disclosure_line.dart';

/// Review 02 F4/A5: the "Report this result" link wraps as a whole
/// unit or takes its own line — never a mid-link orphan.
void main() {
  tearDown(Get.reset);

  /// The rendered paragraph whose plain text contains [needle].
  Finder richContaining(String needle) =>
      find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          return widget.text.toPlainText().contains(needle);
        }
        return false;
      });

  Future<void> pumpLine(
    WidgetTester tester, {
    required double width,
    required VoidCallback onReport,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: DisclosureLine(onReport: onReport),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('narrow width: the link stays on one line of its own', (
    tester,
  ) async {
    await pumpLine(tester, width: 220, onReport: () {});
    final linkChunk = richContaining('Report this result');
    expect(linkChunk, findsOneWidget);
    // A single bodySm line is ~18dp tall; a mid-link split would
    // double the height of the chunk carrying the link text.
    expect(tester.getSize(linkChunk).height, lessThan(24));
    expect(
      find.text('Processed securely · Original deleted from server'),
      findsOneWidget,
    );
  });

  testWidgets('tapping the link fires the report callback', (tester) async {
    var reported = false;
    await pumpLine(tester, width: 400, onReport: () => reported = true);
    final chunk = tester.getRect(richContaining('Report this result'));
    // The link occupies the right end of its chunk; tap there.
    await tester.tapAt(Offset(chunk.right - 6, chunk.center.dy));
    expect(reported, isTrue);
  });
}
