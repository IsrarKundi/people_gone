import 'dart:math' as math;

/// Cam mascot — expression state machine, V2 version.
///
/// The character is the owner's approved V2 artwork itself (see
/// [CamMascotArt]): two poses, Home (waving) and Analyzing, and
/// Processing reuses the Analyzing pose exactly — no monitor, no
/// per-screen redraw. Life comes from motion that matches the
/// scene he is in — not one generic loop on every screen. All
/// motion is transform-only on the app's calm-motion timing (no
/// bounce, no sparkles, no overshoot):
///
/// * Home (avatar): friendly welcome — slow breathing, a blink
///   every 4 s, a gentle side-to-side sway, and a waving arm
///   rocking on a 2 s cycle.
/// * Analyzing: curious and focused — a slow left-to-right scan,
///   leaning into the scan direction, blinking half as often
///   because he is concentrating, mouth curious.
/// * Review (avatarSmall, shared with Brush / History): calm
///   company only — breathing and a slow blink, nothing that
///   distracts from precise work or browsing. Review's nod on a
///   tap is a one-shot reaction in [CamMascot], not this loop.
/// * Processing: the same Analyzing pose, busy — a small bob,
///   a blink every 4 s, and a one-second glance up toward the
///   user every 12 s, like a quick check-in, then back to work.
/// * Result (resultsReady): pleased — the same calm welcome loop
///   as Home; the arrival pulse is a one-shot in [CamMascot].
/// * Concerned (any mode, `concerned: true`): sorry, not alarmed
///   — slower breathing, a constant gentle head droop, a frown,
///   and a blink half as often. Used on the processing failure
///   screen.
///
/// Modes follow the owner's journey: [CamMode.avatar] = Home
/// top-right circle; [CamMode.analyzing] = screen-centre,
/// whole and uncropped; [CamMode.processing] = the same
/// Analyzing pose, screen-centre, whole and uncropped;
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

/// The mouth expression drawn in code over the V2 art (the original
/// smile is painted out of the base assets, so the mouth is a
/// separate layer like the pupils).
enum CamMouth {
  /// Small closed smile: quiet company, focused work.
  smile,

  /// Big open happy smile: Home welcome, Result success.
  openSmile,

  /// Small curious open mouth: Analyzing a photo.
  curious,

  /// Downturned frown: failure / concerned screens.
  frown,
}

/// One evaluated frame of the mascot.
class CamFrame {
  const CamFrame({
    required this.breath,
    required this.blink,
    required this.tilt,
    required this.shiftX,
    required this.shiftY,
    required this.gazeX,
    required this.gazeY,
    this.mouth = CamMouth.smile,
    this.waveAngle = 0,
  });

  /// The still frame: reduced motion, and the timeline's resting state.
  static const CamFrame neutral = CamFrame(
    breath: 1,
    blink: 0,
    tilt: 0,
    shiftX: 0,
    shiftY: 0,
    gazeX: 0,
    gazeY: 0,
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

  /// Pupil gaze inside the eye whites, -1 (left / up) to 1.
  /// Drives the puppet pupils in [CamMascotArt]; the sheet body
  /// itself does not move with the gaze.
  final double gazeX;

  /// Pupil gaze, -1 (up) to 1 (down).
  final double gazeY;

  /// Mouth expression for this frame (see [CamMouth]).
  final CamMouth mouth;

  /// Waving-arm angle in radians, Home only. A calm 2 s rock,
  /// ±0.18 rad, so the wave loops seamlessly over 24 s.
  final double waveAngle;

  @override
  bool operator ==(Object other) =>
      other is CamFrame &&
      other.breath == breath &&
      other.blink == blink &&
      other.tilt == tilt &&
      other.shiftX == shiftX &&
      other.shiftY == shiftY &&
      other.gazeX == gazeX &&
      other.gazeY == gazeY &&
      other.mouth == mouth &&
      other.waveAngle == waveAngle;

  @override
  int get hashCode => Object.hash(
    breath,
    blink,
    tilt,
    shiftX,
    shiftY,
    gazeX,
    gazeY,
    mouth,
    waveAngle,
  );
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
  final double breath = 1 + 0.012 * math.sin(2 * math.pi * td / breathPeriod);

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
          final double g = math.sin(math.pi * (glanceCycle - 8000) / 1000);
          tilt += -0.035 * g;
          shiftX += -2 * g;
        }
    }
  }

  // Puppet gaze per scene: pupils look where the scene looks.
  double gazeX = 0;
  double gazeY = 0;
  if (concerned) {
    gazeY = 0.45;
  } else {
    switch (mode) {
      case CamMode.avatar:
        gazeX = -0.35 + 0.2 * math.sin(2 * math.pi * td / 12000);
        gazeY = 0.15;
      case CamMode.avatarSmall:
        gazeX = -0.2;
        gazeY = 0.1;
      case CamMode.analyzing:
        gazeX = 0.7 * math.sin(2 * math.pi * td / 8000);
        gazeY = 0.1 * math.sin(2 * math.pi * td / 8000 + math.pi / 2);
      case CamMode.processing:
        gazeX = 0.55;
        gazeY = 0;
        final double glanceCycle = td % 12000;
        if (glanceCycle >= 8000 && glanceCycle <= 9000) {
          gazeY = -0.6 * math.sin(math.pi * (glanceCycle - 8000) / 1000);
        }
      case CamMode.resultsReady:
        gazeX = 0;
        gazeY = 0.3;
    }
  }

  // Mouth expression is part of the scene, not a motion: Home and
  // Result are openly happy, Analyzing is curious, focused work
  // keeps a small smile, and concerned frowns.
  final CamMouth mouth;
  if (concerned) {
    mouth = CamMouth.frown;
  } else {
    switch (mode) {
      case CamMode.avatar:
      case CamMode.resultsReady:
        mouth = CamMouth.openSmile;
      case CamMode.analyzing:
        mouth = CamMouth.curious;
      case CamMode.avatarSmall:
      case CamMode.processing:
        mouth = CamMouth.smile;
    }
  }

  // Home wave: the raised arm rocks ±0.18 rad on a 2 s cycle.
  // Every other mode keeps the arm still.
  final double waveAngle =
      mode == CamMode.avatar && !concerned
          ? 0.18 * math.sin(2 * math.pi * td / 2000)
          : 0;

  return CamFrame(
    breath: breath,
    blink: blink,
    tilt: tilt,
    shiftX: shiftX,
    shiftY: shiftY,
    gazeX: gazeX,
    gazeY: gazeY,
    mouth: mouth,
    waveAngle: waveAngle,
  );
}
