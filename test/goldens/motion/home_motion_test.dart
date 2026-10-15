import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/features/home/widgets/home_job_banner.dart';
import 'package:people_gone/features/home/widgets/interactive_demo_card.dart';
import 'package:people_gone/services/processing/job_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home Motion (Items #4, #5, #6)', () {
    testWidgets('Demo card animates teaching sweep once and touch cancels it', (tester) async {
      InteractiveDemoCard.hasRunTeachingSweep = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              width: 360,
              child: InteractiveDemoCard(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Animating toward 0.32
      await tester.pump(const Duration(milliseconds: 300));

      // Touch cancels sweep immediately
      await tester.tap(find.byType(InteractiveDemoCard));
      await tester.pump();

      // Subsequent session does not run again
      expect(InteractiveDemoCard.hasRunTeachingSweep, isTrue);
    });

    testWidgets('Demo card sweep is skipped under reduced motion', (tester) async {
      InteractiveDemoCard.hasRunTeachingSweep = false;

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                width: 360,
                child: InteractiveDemoCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(InteractiveDemoCard), findsOneWidget);
    });

    testWidgets('Job banner enters with slide-down + fade and captures golden', (tester) async {
      final job = ActiveJob(
        photoPath: 'test.jpg',
        status: ActiveJobStatus.processing,
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: HomeJobBanner(job: job),
            ),
          ),
        ),
      );

      // Mid-entry frame (t = 150ms)
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        find.descendant(
          of: find.byType(HomeJobBanner),
          matching: find.byType(SlideTransition),
        ),
        findsOneWidget,
      );

      // Finish 300ms entrance
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(
        find.byType(HomeJobBanner),
        matchesGoldenFile('home_banner_processing.png'),
      );
    });

    testWidgets('Job banner animates on status change', (tester) async {
      final job = ActiveJob(
        photoPath: 'test.jpg',
        status: ActiveJobStatus.processing,
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: HomeJobBanner(job: job),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      final doneJob = job.copyWith(status: ActiveJobStatus.done);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: HomeJobBanner(job: doneJob),
            ),
          ),
        ),
      );

      // Status change triggered re-entry animation
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byType(HomeJobBanner),
          matching: find.byType(SlideTransition),
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 250));
      await expectLater(
        find.byType(HomeJobBanner),
        matchesGoldenFile('home_banner_done.png'),
      );
    });
  });
}
