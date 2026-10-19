import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/features/home/widgets/interactive_demo_card.dart';
import 'package:people_gone/features/result/widgets/compare_slider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sampleOrig;
  late File sampleRes;
  final hapticCalls = <String>[];

  setUp(() async {
    CompareSlider.hasRunCompareNudge = true;
    InteractiveDemoCard.hasRunTeachingSweep = true;
    hapticCalls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method.startsWith('HapticFeedback.')) {
            hapticCalls.add(call.arguments as String? ?? call.method);
          }
          return null;
        });

    tempDir = await Directory.systemTemp.createTemp('compare_slider_haptics_');
    sampleOrig = File('${tempDir.path}/orig.jpg');
    sampleRes = File('${tempDir.path}/res.jpg');
    // Minimal valid 1x1 JPEG bytes
    final bytes = <int>[
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
      0x00, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x03, 0x03, 0x03, 0x04,
      0x06, 0x04, 0x04, 0x04, 0x04, 0x04, 0x08, 0x06, 0x06, 0x05, 0x06, 0x09,
      0x08, 0x0A, 0x0A, 0x09, 0x08, 0x09, 0x09, 0x0A, 0x0C, 0x0F, 0x0C, 0x0A,
      0x0B, 0x0E, 0x0B, 0x09, 0x09, 0x0D, 0x11, 0x0D, 0x0E, 0x0F, 0x10, 0x10,
      0x11, 0x10, 0x0A, 0x0C, 0x12, 0x13, 0x12, 0x10, 0x13, 0x0F, 0x10, 0x10,
      0x10, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01,
      0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01,
      0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0xFF,
      0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0x7F, 0x00, 0xFF,
      0xD9,
    ];
    await sampleOrig.writeAsBytes(bytes);
    await sampleRes.writeAsBytes(bytes);
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Widget wrapWithTheme(Widget child) {
    return GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('CompareSlider haptic fires ONLY when crossing removed person centers', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 800);
    addTearDown(tester.view.reset);

    // 2 removed people at 30% (0.3) and 70% (0.7)
    await tester.pumpWidget(
      wrapWithTheme(
        SizedBox(
          width: 1000,
          height: 800,
          child: CompareSlider(
            originalPath: sampleOrig.path,
            resultPath: sampleRes.path,
            removedCenters: const <double>[0.3, 0.7],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    hapticCalls.clear();

    // Divider starts at 0.5 (x = 500)
    // 1. Drag from x = 500 to x = 400 (fraction 0.5 -> 0.4): No person crossed!
    final gesture = await tester.startGesture(const Offset(500, 400));
    await gesture.moveTo(const Offset(400, 400));
    await tester.pump();
    expect(hapticCalls, isEmpty, reason: 'No person at 0.4..0.5 so no tick');

    // 2. Drag across 0.3 (x = 400 to x = 200, crossing 0.3 at x = 300)
    await gesture.moveTo(const Offset(200, 400));
    await tester.pump();
    expect(
      hapticCalls,
      <String>['HapticFeedbackType.selectionClick'],
      reason: 'Crossed person at 0.3, exactly one tick fired',
    );
    hapticCalls.clear();

    // 3. Drag to edge (x = 0): edge/boundary tick fires
    await gesture.moveTo(const Offset(0, 400));
    await tester.pump();
    expect(
      hapticCalls,
      <String>['HapticFeedbackType.selectionClick'],
      reason: 'Boundary tick at edge',
    );
    hapticCalls.clear();

    // 4. Full drag across entire width: x = 0 to x = 1000
    // Crosses person at 0.3 and person at 0.7, plus edge at 1.0
    await gesture.moveTo(const Offset(1000, 400));
    await tester.pump();
    // 2 selection clicks for the 2 removed persons, 1 boundary click for the edge
    expect(hapticCalls.length, 3);
    await gesture.up();
  });

  testWidgets('CompareSlider with no removed persons NEVER ticks during drag', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithTheme(
        SizedBox(
          width: 1000,
          height: 800,
          child: CompareSlider(
            originalPath: sampleOrig.path,
            resultPath: sampleRes.path,
            removedCenters: const <double>[], // No removed people
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    hapticCalls.clear();

    final gesture = await tester.startGesture(const Offset(500, 400));
    await gesture.moveTo(const Offset(200, 400));
    await tester.pump();
    await gesture.moveTo(const Offset(800, 400));
    await tester.pump();
    expect(hapticCalls, isEmpty, reason: 'No removed people = no tick ever');
    await gesture.up();
  });

  testWidgets('InteractiveDemoCard ticks ONLY when crossing demo removed centers', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithTheme(
        const SizedBox(
          width: 1000,
          height: 400,
          child: InteractiveDemoCard(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    hapticCalls.clear();

    // Initial fraction is 0.5 (x = 500)
    // Drag in empty area: 0.5 to 0.6 (no person between 0.5 and 0.6; barista is at ~0.764)
    final gesture = await tester.startGesture(const Offset(500, 200));
    await gesture.moveTo(const Offset(600, 200));
    await tester.pump();
    expect(hapticCalls, isEmpty, reason: 'No person in 0.5..0.6');

    // Drag across barista (~0.764, x = 764) to x = 850
    await gesture.moveTo(const Offset(850, 200));
    await tester.pump();
    expect(hapticCalls.length, 1, reason: 'Crossed barista at ~0.764');
    hapticCalls.clear();

    await gesture.up();
  });
}
