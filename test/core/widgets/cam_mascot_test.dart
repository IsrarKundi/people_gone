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

  testWidgets('test environment freezes the ticker but still renders', (
    tester,
  ) async {
    // Regression guard: Cam's production idle loop repeats forever,
    // which would block pumpAndSettle in any host-screen test. Under
    // flutter test he must render the still neutral frame instead, so
    // screens containing him stay settle-able. (Frame motion itself
    // is covered by the pure evaluateCamFrame unit tests.)
    await pumpCam(tester, CamMode.peek);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );
    expect(find.byType(CamMascot), findsOneWidget);
    expect(camPainter(tester).frame, CamFrame.neutral);
  });
}
