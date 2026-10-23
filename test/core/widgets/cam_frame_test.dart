import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/core/widgets/cam_frame.dart';

/// The rig's state machine is pure logic, so its contract — the closed
/// expression set, calm timing, and per-mode glance targets — is pinned
/// here without a single pixel (ADR docs/architecture/cam-mascot.md).
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

    test('blink lands fully closed at ~1.58 s in every mode', () {
      for (final mode in CamMode.values) {
        final frame = evaluateCamFrame(
          const Duration(milliseconds: 1580),
          mode,
        );
        expect(frame.lid, 1, reason: '$mode blink should be closed');
      }
    });

    test('eyes are open between beats', () {
      for (final mode in CamMode.values) {
        final frame = evaluateCamFrame(
          const Duration(milliseconds: 2000),
          mode,
        );
        expect(frame.lid, 0, reason: '$mode should be open at 2 s');
        expect(frame.pupilDx, 0);
        expect(frame.pupilDy, 0);
      }
    });

    test('glance targets are per mode and fully held at 3.4 s', () {
      const at = Duration(milliseconds: 3400);
      expect(evaluateCamFrame(at, CamMode.avatar).pupilDx, -4.5);
      expect(evaluateCamFrame(at, CamMode.avatar).pupilDy, 0.5);
      expect(evaluateCamFrame(at, CamMode.peek).pupilDx, -5.5);
      expect(evaluateCamFrame(at, CamMode.peek).pupilDy, 1.0);
      expect(evaluateCamFrame(at, CamMode.presenter).pupilDx, 0);
      expect(evaluateCamFrame(at, CamMode.presenter).pupilDy, -4.0);
    });

    test('head tilt follows the glance, presenter never tilts', () {
      const at = Duration(milliseconds: 3400);
      expect(evaluateCamFrame(at, CamMode.avatar).tilt, -0.035);
      expect(evaluateCamFrame(at, CamMode.peek).tilt, -0.05);
      expect(evaluateCamFrame(at, CamMode.presenter).tilt, 0);
    });

    test('peek has the slow calm-wait blink; other modes do not', () {
      const at = Duration(milliseconds: 6225);
      expect(evaluateCamFrame(at, CamMode.peek).lid, 1);
      expect(evaluateCamFrame(at, CamMode.avatar).lid, 0);
      expect(evaluateCamFrame(at, CamMode.presenter).lid, 0);
    });

    test('smile is gentle and bounded in every mode', () {
      for (final mode in CamMode.values) {
        for (int ms = 0; ms < 8000; ms += 100) {
          final frame = evaluateCamFrame(Duration(milliseconds: ms), mode);
          expect(frame.smile, inInclusiveRange(0, 1), reason: '$mode @$ms');
          expect(frame.lid, inInclusiveRange(0, 1), reason: '$mode @$ms');
        }
      }
    });

    test('breathing stays within ±1.2 %', () {
      for (int ms = 0; ms < 8000; ms += 137) {
        final frame = evaluateCamFrame(
          Duration(milliseconds: ms),
          CamMode.presenter,
        );
        expect(frame.breath, inInclusiveRange(0.988, 1.012), reason: '@$ms');
      }
    });

    test('deterministic and loops seamlessly', () {
      for (final mode in CamMode.values) {
        final a = evaluateCamFrame(const Duration(milliseconds: 3400), mode);
        final b = evaluateCamFrame(const Duration(milliseconds: 3400), mode);
        final wrapped = evaluateCamFrame(
          const Duration(milliseconds: 3400 + 8000),
          mode,
        );
        expect(a, b);
        expect(a, wrapped, reason: '$mode should wrap onto itself');
      }
    });
  });
}
