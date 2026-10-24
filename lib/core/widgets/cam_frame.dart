import 'dart:math' as math;

/// Cam mascot — expression state machine, sheet-art version.
///
/// The character is the owner's approved 4-panel sheet artwork
/// itself (see [CamMascotArt]): each state is a complete drawing
/// with its own face, so there is no redrawn rig. Life comes from
/// motion that matches the scene he is in — not one generic loop
/// on every screen. All motion is transform-only on the app's
/// calm-motion timing (no bounce, no sparkles, no overshoot):
///
/// * Home (avatar): friendly welcome — slow breathing, a blink
///   every 4 s, and a gentle side-to-side sway like waving hello.
/// * Analyzing: curious and focused — a slow left-to-right scan,
///   leaning into the scan direction, blinking half as often
///   because he is concentrating.
/// * Review (avatarSmall, shared with Brush / History): calm
///   company only — breathing and a slow blink, nothing that
///   distracts from precise work or browsing. Review's nod on a
///   tap is a one-shot reaction in [CamMascot], not this loop.
/// * Processing: busy at the computer — a small typing bob,
///   a blink every 4 s, and a one-second glance up toward the
///   user every 12 s, like a quick check-in, then back to work.
/// * Result (resultsReady): pleased — the same calm welcome loop
///   as Home; the arrival pulse is a one-shot in [CamMascot].
/// * Concerned (any mode, `concerned: true`): sorry, not alarmed
///   — slower breathing, a constant gentle head droop, and a
///   blink half as often. Used on the processing failure screen.
///
/// Modes follow the owner's journey: [CamMode.avatar] = Home
/// top-right circle; [CamMode.analyzing] = screen-centre
/// magnifier, whole and uncropped; [CamMode.processing] =
/// screen-centre at-computer, whole and uncropped;
/// [CamMode.resultsReady] = Result top-right circle (green ring).
/// [CamMode.avatarSmall] = the same code-drawn circle, smaller,
/// for Review / Brush / History headers.
enum CamMode {
  /// Home header: 44dp circle, code-drawn ring.
  avatar,

  /// Small header avatar (Review, Brush, History, History detail):
  /// 32dp circle.
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
    required this.shiftX,
    required this.shiftY,
  });

  /// The still frame: reduced motion, and the timeline's resting state.
  static const CamFrame neutral = CamFrame(
    breath: 1,
    blink: 0,
    tilt: 0,
    shiftX: 0,
    shiftY: 0,
  );

  /// Breathing scale around the ground line (1 = rest).
  final double breath;

  /// Eyelid closure, 0 (eyes open) to 1 (eyes fully closed).
  final double blink;

  /// Lean angle in radians.
  final double tilt;

  /// Sideways shift in dp (scan, sway, glance).
  final double shiftX;

  /// Vertical shift in dp (typing bob, nod, droop are tilt, not this).
  final double shiftY;

  @override
  bool operator ==(Object other) =>
      other is CamFrame &&
      other.breath == breath &&
      other.blink == blink &&
      other.tilt == tilt &&
      other.shiftX == shiftX &&
      other.shiftY == shiftY;

  @override
  int get hashCode => Object.hash(breath, blink, tilt, shiftX, shiftY);
}

/// The idle loop length: the least common multiple of every motion
/// period used below (4 s, 6 s, 8 s, 12 s, 0.5 s), so every motion
/// returns to its resting value at the loop seam, seamlessly.
const Duration camLoopDuration = Duration(milliseconds: 24000);

/// Blink value for a blink window inside one blink cycle: 0 outside
/// the window, rising to 1 at the window's middle, back to 0.
double _blinkAt(double cycleMs, double windowStart, double windowMs) {
  if (cycleMs < windowStart || cycleMs > windowStart + windowMs) return 0;
  return math.sin(math.pi * (cycleMs - windowStart) / windowMs);
}

/// Evaluates the mascot at [elapsed]. Deterministic: the same inputs
/// always produce the same frame (golden/unit-test friendly).
CamFrame evaluateCamFrame(
  Duration elapsed,
  CamMode mode, {
  bool concerned = false,
}) {
  final int loopMs = camLoopDuration.inMilliseconds;
  int t = elapsed.inMilliseconds % loopMs;
  if (t < 0) t += loopMs;
  final double td = t.toDouble();

  // Breathing: ±1.2 % around the ground line; slower when concerned.
  final double breathPeriod = concerned ? 6000 : 4000;
  final double breath =
      1 + 0.012 * math.sin(2 * math.pi * td / breathPeriod);

  // Blink rate is part of the scene: Home / Processing / Result
  // blink every 4 s; Analyzing and the small headers blink every
  // 8 s / 6 s (focused, or quiet company); concerned blinks every
  // 8 s. One blink is always 160 ms.
  double blink;
  if (concerned) {
    blink = _blinkAt(td % 8000, 3800, 160);
  } else {
    switch (mode) {
      case CamMode.analyzing:
        blink = _blinkAt(td % 8000, 3800, 160);
      case CamMode.avatarSmall:
        blink = _blinkAt(td % 6000, 2800, 160);
      case CamMode.avatar:
      case CamMode.processing:
      case CamMode.resultsReady:
        blink = _blinkAt(td % 4000, 1800, 160);
    }
  }

  // Scene motion.
  double tilt = 0;
  double shiftX = 0;
  double shiftY = 0;
  if (concerned) {
    // Sorry, not alarmed: a constant gentle head droop, no sway.
    tilt = -0.05;
  } else {
    switch (mode) {
      case CamMode.avatar:
      case CamMode.resultsReady:
        // Welcome sway: ±1.5° and ±2 dp on a 4 s cycle.
        final double sway = math.sin(2 * math.pi * td / 4000);
        tilt = 0.026 * sway;
        shiftX = 2 * sway;
      case CamMode.avatarSmall:
        // Quiet company: breathing and blink only.
        break;
      case CamMode.analyzing:
        // Scan: a slow 8 s left-to-right sweep, leaning into it.
        final double scan = math.sin(2 * math.pi * td / 8000);
        shiftX = 6 * scan;
        tilt = 0.02 * scan;
      case CamMode.processing:
        // Typing bob: 2 Hz, ±1.5 dp, on top of a small sway.
        final double sway = math.sin(2 * math.pi * td / 4000);
        tilt = 0.013 * sway;
        shiftX = 1 * sway;
        shiftY = 1.5 * math.sin(2 * math.pi * td / 500);
        // Glance up every 12 s: one second leaning back toward
        // the user, then back to the computer.
        final double glanceCycle = td % 12000;
        if (glanceCycle >= 8000 && glanceCycle <= 9000) {
          final double g =
              math.sin(math.pi * (glanceCycle - 8000) / 1000);
          tilt += -0.035 * g;
          shiftX += -2 * g;
        }
    }
  }

  return CamFrame(
    breath: breath,
    blink: blink,
    tilt: tilt,
    shiftX: shiftX,
    shiftY: shiftY,
  );
}
