import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/core/widgets/cam_frame.dart';

/// The mascot's motion is pure logic, so its contract — calm
/// breathing, one blink per loop, and a gentle lean-and-glance,
/// identical in every mode, deterministic and looping — is pinned
/// here without a single pixel.
void main() {
  group('evaluateCamFrame', () {
    test('resting state at t=0 in every mode', () {
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
        for (int ms = 0; ms < 4000; ms += 100) {
          final frame = evaluateCamFrame(Duration(milliseconds: ms), mode);
          expect(
            frame.breath,
            inInclusiveRange(0.988, 1.012),
            reason: '$mode @$ms',
          );
        }
      }
    });

    test('breathing is the same in every mode at the same time', () {
      for (int ms = 0; ms < 4000; ms += 250) {
        final at = Duration(milliseconds: ms);
        final first = evaluateCamFrame(at, CamMode.avatar);
        for (final mode in CamMode.values) {
          expect(evaluateCamFrame(at, mode), first, reason: '$mode @$ms');
        }
      }
    });

    test('blinks once per loop, 160 ms, fully closed at the peak', () {
      for (final mode in CamMode.values) {
        final peak = evaluateCamFrame(
          const Duration(milliseconds: 1880),
          mode,
        );
        expect(peak.blink, closeTo(1, 0.001), reason: '$mode peak');
        for (final ms in <int>[0, 1000, 1700, 2000, 3000]) {
          expect(
            evaluateCamFrame(Duration(milliseconds: ms), mode).blink,
            0,
            reason: '$mode @$ms must not blink',
          );
        }
      }
    });

    test('lean and glance stay gentle and return to rest at t=0', () {
      for (final mode in CamMode.values) {
        for (int ms = 0; ms < 4000; ms += 100) {
          final frame = evaluateCamFrame(Duration(milliseconds: ms), mode);
          expect(frame.tilt.abs(), lessThanOrEqualTo(0.027));
          expect(frame.shift.abs(), lessThanOrEqualTo(2.001));
        }
        expect(
          evaluateCamFrame(Duration.zero, mode).tilt,
          0,
          reason: '$mode tilt at rest',
        );
        expect(
          evaluateCamFrame(Duration.zero, mode).shift,
          0,
          reason: '$mode shift at rest',
        );
      }
    });

    test('deterministic and loops seamlessly', () {
      for (final mode in CamMode.values) {
        final a = evaluateCamFrame(const Duration(milliseconds: 1000), mode);
        final b = evaluateCamFrame(const Duration(milliseconds: 1000), mode);
        final wrapped = evaluateCamFrame(
          const Duration(milliseconds: 1000 + 4000),
          mode,
        );
        expect(a, b);
        expect(a, wrapped, reason: '$mode should wrap onto itself');
      }
    });
  });
}
