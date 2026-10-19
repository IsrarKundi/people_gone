import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/constants/app_motion.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/home/widgets/interactive_demo_card.dart';
import 'package:people_gone/services/storage/local_store.dart';

class _TestLocalStore implements LocalStore {
  bool isIntroSeen = false;
  int setIntroSeenCalls = 0;

  @override
  Future<Result<bool>> introSeen() async => Success<bool>(isIntroSeen);

  @override
  Future<Result<void>> setIntroSeen() async {
    isIntroSeen = true;
    setIntroSeenCalls++;
    return const Success<void>(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    Get.reset();
    InteractiveDemoCard.hasRunTeachingSweep = false;
  });

  Widget createApp({
    required LocalStore store,
    bool disableAnimations = false,
  }) {
    return GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: InteractiveDemoCard(localStore: store),
          ),
        ),
      ),
    );
  }

  group('First-run choreography (brief §2-§5)', () {
    testWidgets(
      'first launch arms intro_seen_v1 immediately (write-then-play) and delays sweep by 400ms',
      (tester) async {
        final store = _TestLocalStore()..isIntroSeen = false;

        await tester.pumpWidget(createApp(store: store));
        await tester.pump(); // frame 1
        await tester.pump(const Duration(milliseconds: 50)); // post-frame arming

        // Flag is written before playing (write-then-play, §4)
        expect(store.setIntroSeenCalls, 1);
        expect(store.isIntroSeen, isTrue);

        // At 200ms (before 400ms delay), sweep has NOT started (fraction is still 0.5)
        await tester.pump(const Duration(milliseconds: 150));
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.value == '50%',
          ),
          findsOneWidget,
        );

        // At 400ms + 50ms, the sweep has begun and moves toward 0.32
        await tester.pump(AppMotion.firstRunSweepDelay);
        await tester.pump(const Duration(milliseconds: 200));

        // After return leg finishes and settles back to 0.5
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.value == '50%',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('user touch on card during 400ms delay cancels the sweep', (
      tester,
    ) async {
      final store = _TestLocalStore()..isIntroSeen = false;

      await tester.pumpWidget(createApp(store: store));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(store.setIntroSeenCalls, 1);

      // User drags during the 400ms delay (at 100ms)
      await tester.pump(const Duration(milliseconds: 100));
      await tester.drag(
        find.byType(InteractiveDemoCard),
        const Offset(120, 0),
      );
      await tester.pump();

      // Drag moved fraction from 0.5 to 0.8 -> 80%
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.value == '80%',
        ),
        findsOneWidget,
      );

      // Advance past the remaining delay + sweep duration; the sweep should NEVER run
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 600));

      // It must stay at the user's dragged position (80%), not reset or sweep
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.value == '80%',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cancelActiveSweep during 400ms delay cancels the sweep', (
      tester,
    ) async {
      final store = _TestLocalStore()..isIntroSeen = false;

      await tester.pumpWidget(createApp(store: store));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // External action (like tapping Pick button) cancels active sweep
      InteractiveDemoCard.cancelActiveSweep();

      // Advance past delay
      await tester.pump(AppMotion.firstRunSweepDelay);
      await tester.pump(const Duration(milliseconds: 200));

      // Stays at 50%
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.value == '50%',
        ),
        findsOneWidget,
      );
    });

    testWidgets('reduced motion: arms flag but sweep NEVER runs', (
      tester,
    ) async {
      final store = _TestLocalStore()..isIntroSeen = false;

      await tester.pumpWidget(
        createApp(store: store, disableAnimations: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Flag was set
      expect(store.setIntroSeenCalls, 1);
      expect(store.isIntroSeen, isTrue);

      // Advance time through delay and sweep
      await tester.pump(AppMotion.firstRunSweepDelay);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 600));

      // Stays at 50% (static card, §5)
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.value == '50%',
        ),
        findsOneWidget,
      );
    });

    testWidgets('later launch (intro already seen): no 400ms delay', (
      tester,
    ) async {
      final store = _TestLocalStore()..isIntroSeen = true;

      await tester.pumpWidget(createApp(store: store));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Flag was not set again
      expect(store.setIntroSeenCalls, 0);

      // Sweep started immediately (no 400ms delay), so after 200ms it is moving
      await tester.pump(const Duration(milliseconds: 200));

      // After completing full cycle
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.value == '50%',
        ),
        findsOneWidget,
      );
    });
  });
}
