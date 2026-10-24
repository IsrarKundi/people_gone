import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/core/widgets/cam_frame.dart';

/// The mascot's motion is pure logic, so its contract — calm
/// breathing only, identical in every mode, deterministic and
/// looping — is pinned here without a single pixel.
///
/// Sheet-art note: each state is a complete sheet drawing with its
/// own face, so there is no blink / glance / tilt rig any more.
/// The frame carries breathing scale only.
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
