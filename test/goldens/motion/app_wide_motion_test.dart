import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/core/constants/app_motion.dart';
import 'package:people_gone/core/routes/page_transitions.dart';
import 'package:people_gone/core/widgets/pressable_scale.dart';
import 'package:people_gone/core/widgets/primary_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App-wide Motion Tokens & Press Scale', () {
    test('AppMotion tokens define fast (180ms) and standard (300ms)', () {
      expect(AppMotion.fast, const Duration(milliseconds: 180));
      expect(AppMotion.standard, const Duration(milliseconds: 300));
      expect(AppMotion.demoSweep, const Duration(milliseconds: 1200));
      expect(AppMotion.compareNudge, const Duration(milliseconds: 600));
      expect(AppMotion.saveHold, const Duration(milliseconds: 1200));
      expect(AppMotion.strokeFade, const Duration(milliseconds: 150));
      expect(AppMotion.themeCrossfade, const Duration(milliseconds: 250));
    });

    testWidgets('PressableScale scales to 0.98 on press with spring-back', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: PrimaryButton(
                  labelKey: 'Test Button',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Unpressed state: scale 1.0
      final scaleInitial = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scaleInitial.scale, 1.0);
      await expectLater(
        find.byType(PrimaryButton),
        matchesGoldenFile('press_scale_unpressed.png'),
      );

      // Press down
      final gesture = await tester.startGesture(tester.getCenter(find.text('Test Button')));
      await tester.pump(const Duration(milliseconds: 180));

      // Pressed state: scale 0.98
      final scalePressed = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scalePressed.scale, 0.98);
      await expectLater(
        find.byType(PrimaryButton),
        matchesGoldenFile('press_scale_pressed.png'),
      );


      // Release
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();

      final scaleReleased = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scaleReleased.scale, 1.0);
    });

    testWidgets('PressableScale stays 1.0 under reduced motion', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: PressableScale(
                  child: Text('Reduced Motion'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.text('Reduced Motion')));
      await tester.pump(const Duration(milliseconds: 50));

      final scaleWidget = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scaleWidget.scale, 1.0);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('PeopleGonePageTransition builds transition widget', (tester) async {
      final transition = PeopleGonePageTransition();
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: AppMotion.standard,
      );

      final widget = Builder(
        builder: (context) {
          return transition.buildTransition(
            context,
            AppMotion.standardCurve,
            Alignment.center,
            controller,
            kAlwaysDismissedAnimation,
            const Text('Transition Page Content'),
          );
        },
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: widget,
        ),
      );

      expect(find.byType(SlideTransition), findsOneWidget);
      expect(find.byType(FadeTransition), findsOneWidget);
      expect(find.text('Transition Page Content'), findsOneWidget);

      controller.dispose();
    });
  });
}
