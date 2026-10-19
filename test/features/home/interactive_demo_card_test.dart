import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/features/home/widgets/interactive_demo_card.dart';

void main() {
  setUp(() {
    Get.reset();
    InteractiveDemoCard.hasRunTeachingSweep = false;
  });

  Widget createApp() {
    return GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      theme: AppTheme.light(),
      home: const Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: InteractiveDemoCard(),
        ),
      ),
    );
  }

  group('InteractiveDemoCard', () {
    testWidgets('starts teaching sweep with calm spring and returns to center', (
      tester,
    ) async {
      await tester.pumpWidget(createApp());
      await tester.pump();

      // Post-frame callback starts the sweep
      await tester.pump(const Duration(milliseconds: 50));

      // After first leg reaches near 0.32 (revealing cleaned)
      await tester.pump(const Duration(milliseconds: 200));

      // After return leg settles back to 0.5
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));

      // Semantic slider should be at 50%
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.value == '50%',
        ),
        findsOneWidget,
      );
    });

    testWidgets('user drag cancels teaching sweep and sets fraction', (
      tester,
    ) async {
      await tester.pumpWidget(createApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // User drags
      await tester.drag(
        find.byType(InteractiveDemoCard),
        const Offset(120, 0),
      );
      await tester.pump();

      // Dragging 120px on 400px width moves fraction from 0.5 (200px) to 0.8 (320px) -> 80%
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.value == '80%',
        ),
        findsOneWidget,
      );
    });
  });
}
