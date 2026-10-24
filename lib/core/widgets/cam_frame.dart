import 'dart:math' as math;

/// Cam mascot — expression state machine, sheet-art version.
///
/// The character is the owner's approved 4-panel sheet artwork
/// itself (see [CamMascotArt]): each state is a complete drawing
/// with its own face, so there is no redrawn rig. Life comes from
/// three calm motions applied to those drawings, all on the app's
/// calm-motion timing (transform + opacity only, no bounce, no
/// sparkles, no overshoot):
///
/// * breathing — a slow scale, ±1.2 % over a 4 s cycle;
/// * blinking — one blink per 4 s loop, 160 ms, shown by swapping
///   to the matching `*_blink.webp` asset (same drawing, eyes
///   painted closed) while the blink value is high;
/// * a gentle lean-and-glance — up to ±1.5° tilt and ±2 dp sideways
///   shift on the same 4 s cycle, so he looks alive while waiting
///   without ever leaving his place on screen.
///
/// Modes follow the owner's journey, not the old v2 map:
/// [CamMode.avatar] = Home top-right circle; [CamMode.analyzing] =
/// screen-centre magnifier, whole and uncropped; [CamMode.processing]
/// = screen-centre at-computer, whole and uncropped;
/// [CamMode.resultsReady] = Result top-right circle (green ring).
/// [CamMode.avatarSmall] = the same code-drawn circle, smaller, for
/// Brush / History headers.
enum CamMode {
  /// Home header: 44dp circle, code-drawn ring.
  avatar,

  /// Small header avatar (Brush, History, History detail): 32dp circle.
  avatarSmall,

  /// Analyzing: full magnifier drawing, centred, uncropped.
  analyzing,

  /// Processing: full at-computer drawing, centred, uncropped.
  processing,

  /// Result header: 44dp circle, code-drawn green ring.
  resultsReady,
}

/// One evaluated frame of the mascot.
class CamFrame {
  const CamFrame({
    required this.breath,
    required this.blink,
    required this.tilt,
    required this.shift,
  });

  /// The still frame: reduced motion, and the timeline's resting state.
  static const CamFrame neutral = CamFrame(
    breath: 1,
    blink: 0,
    tilt: 0,
    shift: 0,
  );

  /// Breathing scale around the ground line (1 = rest).
  final double breath;

  /// Eyelid closure, 0 (eyes open) to 1 (eyes fully closed).
  final double blink;

  /// Lean angle in radians, ±0.026 (±1.5°).
  final double tilt;

  /// Sideways glance shift in dp, ±2.
  final double shift;

  @override
  bool operator ==(Object other) =>
      other is CamFrame &&
      other.breath == breath &&
      other.blink == blink &&
      other.tilt == tilt &&
      other.shift == shift;

  @override
  int get hashCode => Object.hash(breath, blink, tilt, shift);
}

/// The idle loop length. Every motion completes whole cycles per
/// loop, so the loop seam is continuous.
const Duration camLoopDuration = Duration(milliseconds: 4000);

/// Evaluates the mascot at [elapsed]. Deterministic: the same inputs
/// always produce the same frame (golden/unit-test friendly).
CamFrame evaluateCamFrame(Duration elapsed, CamMode mode) {
  // Mode does not change the motion: the character must look
  // identical on every screen, and the sheet faces already differ.
  final int loopMs = camLoopDuration.inMilliseconds;
  int t = elapsed.inMilliseconds % loopMs;
  if (t < 0) t += loopMs;
  final double td = t.toDouble();

  // Breathing: one full cycle per 4 s, ±1.2 % around the ground line.
  final double breath = 1 + 0.012 * math.sin(2 * math.pi * td / 4000);

  // Blink: one 160 ms blink per loop, centred mid-loop so t=0 stays
  // the neutral frame. The curve rises and falls smoothly, so the
  // blink asset is shown only while the value is high.
  double blink = 0;
  if (td >= 1800 && td <= 1960) {
    blink = math.sin(math.pi * (td - 1800) / 160);
  }

  // Lean-and-glance: one slow sway per loop, same phase as the
  // breathing, so at t=0 everything is at rest.
  final double sway = math.sin(2 * math.pi * td / 4000);
  final double tilt = 0.026 * sway;
  final double shift = 2 * sway;

  return CamFrame(breath: breath, blink: blink, tilt: tilt, shift: shift);
}
