import 'dart:math' as math;

/// Cam mascot — expression state machine (ADR docs/architecture/cam-mascot.md).
///
/// Pure, deterministic logic: the widget supplies elapsed time, this file
/// decides the face. One shared timeline design serves all three modes;
/// modes differ only in glance target, tilt, and which beats play, so the
/// character cannot drift between screens. Timing follows the researched
/// idle norms (blink ~every 3.6 s at ~170 ms; glance held ~1 s; breathing
/// ±1.2 %) expressed with the app's calm motion character — ease curves
/// only, no overshoot anywhere.
enum CamMode {
  /// Home header: face only, inside a 44dp circle.
  avatar,

  /// Processing: half the character, peeking from the right screen edge.
  peek,

  /// Paywall: full sitting pose, presenting the plans.
  presenter,
}

/// One evaluated frame of the rig: the only inputs [CamPainter] needs.
class CamFrame {
  const CamFrame({
    required this.lid,
    required this.pupilDx,
    required this.pupilDy,
    required this.smile,
    required this.tilt,
    required this.breath,
  });

  /// The still frame: reduced motion, and the timeline's resting state.
  static const CamFrame neutral = CamFrame(
    lid: 0,
    pupilDx: 0,
    pupilDy: 0,
    smile: 0,
    tilt: 0,
    breath: 1,
  );

  /// Eyelid coverage, 0 (open) → 1 (closed).
  final double lid;

  /// Pupil offset in canvas units (240×240 space).
  final double pupilDx;
  final double pupilDy;

  /// Smile amount, 0 (resting mouth) → 1 (full soft smile).
  final double smile;

  /// Head tilt in radians, around the neck pivot.
  final double tilt;

  /// Breathing scale around the ground line (1 = rest).
  final double breath;

  @override
  bool operator ==(Object other) =>
      other is CamFrame &&
      other.lid == lid &&
      other.pupilDx == pupilDx &&
      other.pupilDy == pupilDy &&
      other.smile == smile &&
      other.tilt == tilt &&
      other.breath == breath;

  @override
  int get hashCode => Object.hash(lid, pupilDx, pupilDy, smile, tilt, breath);
}

/// The idle loop length. Every beat below is placed inside one loop so
/// the sequence repeats seamlessly.
const Duration camLoopDuration = Duration(milliseconds: 8000);

/// Evaluates the rig at [elapsed] for [mode]. Deterministic: the same
/// inputs always produce the same frame (golden/unit-test friendly).
CamFrame evaluateCamFrame(Duration elapsed, CamMode mode) {
  final int loopMs = camLoopDuration.inMilliseconds;
  int t = elapsed.inMilliseconds % loopMs;
  if (t < 0) t += loopMs;
  final double td = t.toDouble();

  // Breathing: one full cycle per 4 s (two per loop, so the loop seam
  // is continuous), ±1.2 % around the ground line.
  final double breath = 1 + 0.012 * math.sin(2 * math.pi * td / 4000);

  // Blinks: a normal ~170 ms blink at 1.5 s in every mode. The second
  // beat is the mode's character: peek gets the slow "calm wait" blink
  // (450 ms) at 6 s; the other modes repeat the normal blink at 5.6 s.
  double lid = _blink(td, 1500, slow: false);
  if (mode == CamMode.peek) {
    lid = math.max(lid, _blink(td, 6000, slow: true));
  } else {
    lid = math.max(lid, _blink(td, 5600, slow: false));
  }

  // Curious glance: ease out over 300 ms (the standard motion token),
  // hold ~1 s, ease back over 300 ms.
  final double glance = _envelope(td, 2600, 2900, 3900, 4200);

  // Glance targets per mode, in canvas units. Avatar and peek look
  // toward the screen's centre (their left); the presenter looks up at
  // the plans above him.
  final (double gx, double gy) = switch (mode) {
    CamMode.avatar => (-4.5, 0.5),
    CamMode.peek => (-5.5, 1.0),
    CamMode.presenter => (0.0, -4.0),
  };

  // Smile: avatar/presenter smile with the glance and linger slightly
  // past it; peek wears a smaller smile only while glancing.
  final double smile = switch (mode) {
    CamMode.peek => 0.7 * glance,
    _ => _envelope(td, 3000, 3300, 4600, 4900),
  };

  // Head tilt follows the glance (the presenter looks straight up, so
  // he does not tilt).
  final double tilt = switch (mode) {
    CamMode.avatar => -0.035 * glance,
    CamMode.peek => -0.05 * glance,
    CamMode.presenter => 0.0,
  };

  return CamFrame(
    lid: lid,
    pupilDx: gx * glance,
    pupilDy: gy * glance,
    smile: smile,
    tilt: tilt,
    breath: breath,
  );
}

/// A blink starting at [startMs]: smooth close, brief hold, smooth
/// open. Normal ≈170 ms total; slow ("calm wait") ≈450 ms.
double _blink(double t, double startMs, {required bool slow}) {
  final double up = slow ? 150 : 55;
  final double hold = slow ? 150 : 35;
  final double down = slow ? 150 : 80;
  final double x = t - startMs;
  if (x < 0 || x > up + hold + down) return 0;
  if (x < up) return _smoothstep(x / up);
  if (x < up + hold) return 1;
  return 1 - _smoothstep((x - up - hold) / down);
}

/// Trapezoid envelope: 0 → 1 across [inStart, inEnd], hold 1 until
/// [outStart], back to 0 at [outEnd]. All edges smoothstepped.
double _envelope(
  double t,
  double inStart,
  double inEnd,
  double outStart,
  double outEnd,
) {
  if (t <= inStart || t >= outEnd) return 0;
  if (t < inEnd) return _smoothstep((t - inStart) / (inEnd - inStart));
  if (t <= outStart) return 1;
  return 1 - _smoothstep((t - outStart) / (outEnd - outStart));
}

double _smoothstep(double x) {
  final double u = x.clamp(0.0, 1.0);
  return u * u * (3 - 2 * u);
}
