import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/widgets/cam_frame.dart';
import 'package:people_gone/core/widgets/cam_mascot.dart';
import 'package:people_gone/core/widgets/cam_painter.dart';

/// Widget contract for Cam (plan §3/§6): the three modes size exactly
/// from the mascot tokens, all three modes render the SAME rig, and
/// reduced motion freezes him on the neutral still frame.
void main() {
  Future<void> pumpCam(
    WidgetTester tester,
    CamMode mode, {
    bool dark = false,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(disableAnimations: reduceMotion),
            child: child!,
          );
        },
        home: Scaffold(
          body: Center(child: CamMascot(mode: mode)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('mode sizes come from the mascot tokens', (tester) async {
    await pumpCam(tester, CamMode.avatar);
    expect(tester.getSize(find.byType(CamMascot)), const Size(44, 44));

    await pumpCam(tester, CamMode.peek);
    expect(tester.getSize(find.byType(CamMascot)), const Size(55, 110));

    await pumpCam(tester, CamMode.presenter);
    expect(tester.getSize(find.byType(CamMascot)), const Size(120, 120));
  });

  // Cam's own CustomPaint, scoped inside the CamMascot subtree (the
  // surrounding app shell contains unrelated painters/builders).
  Finder camPaint() => find.descendant(
    of: find.byType(CamMascot),
    matching: find.byType(CustomPaint),
  );

  CamPainter camPainter(WidgetTester tester) =>
      tester.widget<CustomPaint>(camPaint()).painter! as CamPainter;

  testWidgets('all three modes render the same rig painter', (tester) async {
    for (final mode in CamMode.values) {
      await pumpCam(tester, mode);
      expect(camPainter(tester).mode, mode);
    }
  });

  testWidgets('dark theme renders without error', (tester) async {
    await pumpCam(tester, CamMode.presenter, dark: true);
    expect(find.byType(CamMascot), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion renders the neutral still frame', (tester) async {
    await pumpCam(tester, CamMode.avatar, reduceMotion: true);
    expect(
      find.descendant(
        of: find.byType(CamMascot),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(camPainter(tester).frame, CamFrame.neutral);
    // Time passing changes nothing: he is a still frame.
    await tester.pump(const Duration(seconds: 3));
    expect(camPainter(tester).frame, CamFrame.neutral);
  });

  testWidgets('animated mode advances frames with time', (tester) async {
    await pumpCam(tester, CamMode.peek);
    final first = camPainter(tester).frame;
    await tester.pump(const Duration(milliseconds: 1580));
    final blinked = camPainter(tester).frame;
    expect(blinked.lid, 1, reason: 'peek should be mid-blink at 1.58 s');
    expect(blinked, isNot(first));
  });
}
