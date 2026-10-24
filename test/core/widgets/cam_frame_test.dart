import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/core/widgets/cam_frame.dart';

/// The mascot's motion is pure logic, so its contract — scene-matched
/// motion, identical faces per mode, deterministic and looping —
/// is pinned here without a single pixel.
///
/// Per-mode contract (see cam_frame.dart): Home / Result sway,
/// Analyzing scans and blinks half as often, small headers stay
/// quiet (breathing + blink only), Processing types and glances
/// up, concerned droops slowly.
void main() {
  group('evaluateCamFrame', () {
    test('resting state at t=0 in every non-concerned mode', () {
      for (final mode in CamMode.values) {
        expect(
          evaluateCamFrame(Duration.zero, mode),
          CamFrame.neutral,
          reason: '$mode should start from the neutral frame',
        );
      }
    });

    test('breathing stays within ±1.2 % in every mode', () {
      for (final mode in CamMode.values) {
        for (int ms = 0; ms < 24000; ms += 250) {
          final frame = evaluateCamFrame(Duration(milliseconds: ms), mode);
          expect(
            frame.breath,
            inInclusiveRange(0.988, 1.012),
            reason: '$mode @$ms',
          );
        }
      }
    });

    test('blinks once per its own cycle, 160 ms, fully closed at peak', () {
      // Home / Processing / Result: every 4 s, peak at 1880 ms.
      for (final mode in <CamMode>[
        CamMode.avatar,
        CamMode.processing,
        CamMode.resultsReady,
      ]) {
        expect(
          evaluateCamFrame(const Duration(milliseconds: 1880), mode).blink,
          closeTo(1, 0.001),
          reason: '$mode peak',
        );
        expect(
          evaluateCamFrame(const Duration(milliseconds: 2000), mode).blink,
          0,
          reason: '$mode must not blink at 2000 ms',
        );
      }
      // Analyzing: every 8 s, peak at 3880 ms, and NOT at 1880 ms.
      expect(
        evaluateCamFrame(const Duration(milliseconds: 3880), CamMode.analyzing)
            .blink,
        closeTo(1, 0.001),
      );
      expect(
        evaluateCamFrame(const Duration(milliseconds: 1880), CamMode.analyzing)
            .blink,
        0,
        reason: 'analyzing blinks half as often as Home',
      );
      // Small headers: every 6 s, peak at 2880 ms.
      expect(
        evaluateCamFrame(
          const Duration(milliseconds: 2880),
          CamMode.avatarSmall,
        ).blink,
        closeTo(1, 0.001),
      );
    });

    test('analyzing scans: sideways sweep and lean into it', () {
      final left = evaluateCamFrame(
        const Duration(milliseconds: 2000),
        CamMode.analyzing,
      );
      final right = evaluateCamFrame(
        const Duration(milliseconds: 6000),
        CamMode.analyzing,
      );
      expect(left.shiftX, greaterThan(0), reason: 'scan one way');
      expect(right.shiftX, lessThan(0), reason: 'scan the other way');
      expect(left.shiftX.abs(), lessThanOrEqualTo(6.001));
      expect(left.tilt, greaterThan(0), reason: 'leans into the scan');
    });

    test('processing types and glances up', () {
      // Typing bob: 2 Hz, ±1.5 dp — different sign a quarter
      // second apart, back to the same value after 500 ms.
      final bob0 = evaluateCamFrame(
        const Duration(milliseconds: 0),
        CamMode.processing,
      );
      final bob125 = evaluateCamFrame(
        const Duration(milliseconds: 125),
        CamMode.processing,
      );
      expect(bob0.shiftY, 0);
      expect(bob125.shiftY, closeTo(1.5, 0.001));
      // Glance: during the 8000–9000 ms window of each 12 s cycle
      // he leans back; outside it, the lean is small.
      final glance = evaluateCamFrame(
        const Duration(milliseconds: 8500),
        CamMode.processing,
      );
      final noGlance = evaluateCamFrame(
        const Duration(milliseconds: 2000),
        CamMode.processing,
      );
      expect(glance.tilt, lessThan(noGlance.tilt - 0.02));
    });

    test('small headers stay quiet: no tilt, no shift', () {
      for (int ms = 0; ms < 24000; ms += 250) {
        final frame = evaluateCamFrame(
          Duration(milliseconds: ms),
          CamMode.avatarSmall,
        );
        expect(frame.tilt, 0, reason: 'avatarSmall @$ms');
        expect(frame.shiftX, 0, reason: 'avatarSmall @$ms');
        expect(frame.shiftY, 0, reason: 'avatarSmall @$ms');
      }
    });

    test('concerned droops, breathes slower, and does not sway', () {
      for (int ms = 0; ms < 24000; ms += 250) {
        final frame = evaluateCamFrame(
          Duration(milliseconds: ms),
          CamMode.processing,
          concerned: true,
        );
        expect(frame.tilt, -0.05, reason: 'droop @$ms');
        expect(frame.shiftX, 0, reason: 'no sway @$ms');
        expect(frame.shiftY, 0, reason: 'no bob @$ms');
      }
      // Slower breathing: at 1000 ms a 6 s breath is still rising
      // less than a 4 s breath would be at the same point.
      final slow = evaluateCamFrame(
        const Duration(milliseconds: 1000),
        CamMode.processing,
        concerned: true,
      );
      final fast = evaluateCamFrame(
        const Duration(milliseconds: 1000),
        CamMode.processing,
      );
      expect(slow.breath, lessThan(fast.breath));
    });

    test('deterministic and loops seamlessly over 24 s', () {
      for (final mode in CamMode.values) {
        final a = evaluateCamFrame(const Duration(milliseconds: 1000), mode);
        final b = evaluateCamFrame(const Duration(milliseconds: 1000), mode);
        final wrapped = evaluateCamFrame(
          const Duration(milliseconds: 1000 + 24000),
          mode,
        );
        expect(a, b);
        expect(a, wrapped, reason: '$mode should wrap onto itself');
      }
    });
  });
}
