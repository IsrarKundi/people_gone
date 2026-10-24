import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/widgets/cam_art.dart';
import 'package:people_gone/core/widgets/cam_frame.dart';
import 'package:people_gone/core/widgets/cam_mascot.dart';

/// Widget contract for Cam (sheet-art journey): avatar circles size
/// from the mascot tokens and draw their ring in code; Analyzing and
/// Processing render whole and uncropped at their fixed widths;
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

    await pumpCam(tester, CamMode.avatarSmall);
    expect(tester.getSize(find.byType(CamMascot)), const Size(32, 32));

    await pumpCam(tester, CamMode.resultsReady);
    expect(tester.getSize(find.byType(CamMascot)), const Size(44, 44));

    // Whole, uncropped: fixed width, height from the art's own aspect.
    await pumpCam(tester, CamMode.analyzing);
    final analyzingSize = tester.getSize(find.byType(CamMascot));
    expect(analyzingSize.width, 200);
    expect(analyzingSize.height, closeTo(200 * 670 / 569, 0.5));

    await pumpCam(tester, CamMode.processing);
    final processingSize = tester.getSize(find.byType(CamMascot));
    expect(processingSize.width, 240);
    expect(processingSize.height, closeTo(240 * 706 / 804, 0.5));
  });

  // Cam's art widget, scoped inside the CamMascot subtree (the
  // surrounding app shell contains unrelated painters/builders).
  Finder camArt() => find.descendant(
    of: find.byType(CamMascot),
    matching: find.byType(CamMascotArt),
  );

  CamMascotArt camArtWidget(WidgetTester tester) =>
      tester.widget<CamMascotArt>(camArt());

  testWidgets('every mode renders exactly one image', (tester) async {
    for (final mode in CamMode.values) {
      await pumpCam(tester, mode);
      expect(camArtWidget(tester).mode, mode);
      expect(
        find.descendant(
          of: find.byType(CamMascot),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('avatar circles draw their ring in code', (tester) async {
    await pumpCam(tester, CamMode.avatar);
    // The ring is a code-drawn border, not part of the image: the
    // avatar subtree contains a circular Container with a border.
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(CamMascot),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.border, isNotNull);
  });

  testWidgets('dark theme renders without error', (tester) async {
    await pumpCam(tester, CamMode.processing, dark: true);
    expect(find.byType(CamMascot), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion renders the neutral still frame', (
    tester,
  ) async {
    await pumpCam(tester, CamMode.avatar, reduceMotion: true);
    expect(
      find.descendant(
        of: find.byType(CamMascot),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(camArtWidget(tester).frame, CamFrame.neutral);
    // Time passing changes nothing: he is a still frame.
    await tester.pump(const Duration(seconds: 3));
    expect(camArtWidget(tester).frame, CamFrame.neutral);
  });

  testWidgets('test environment freezes the ticker but still renders', (
    tester,
  ) async {
    // Regression guard: Cam's production idle loop repeats forever,
    // which would block pumpAndSettle in any host-screen test. Under
    // flutter test he must render the still neutral frame instead, so
    // screens containing him stay settle-able. (Frame motion itself
    // is covered by the pure evaluateCamFrame unit tests.)
    await pumpCam(tester, CamMode.processing);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );
    expect(find.byType(CamMascot), findsOneWidget);
    expect(camArtWidget(tester).frame, CamFrame.neutral);
  });
}
