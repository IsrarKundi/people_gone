import 'dart:math' as math;

/// Cam mascot — expression state machine, sheet-art version.
///
/// The character is now the owner's approved 4-panel sheet artwork
/// itself (see [CamMascotArt]): each state is a complete drawing with
/// its own face, so there is no redrawn rig and no eye overlay to
/// move. The only motion left is the calm one the app already allows:
/// a slow breathing scale, ±1.2 % over a 4 s cycle, on the app's
/// calm-motion timing. Everything else about a state — face, pose,
/// props — comes from its sheet drawing, unchanged.
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

/// One evaluated frame of the mascot: breathing scale only.
class CamFrame {
  const CamFrame({required this.breath});

  /// The still frame: reduced motion, and the timeline's resting state.
  static const CamFrame neutral = CamFrame(breath: 1);

  /// Breathing scale around the ground line (1 = rest).
  final double breath;

  @override
  bool operator ==(Object other) =>
      other is CamFrame && other.breath == breath;

  @override
  int get hashCode => breath.hashCode;
}

/// The idle loop length. Breathing completes one cycle per loop, so
/// the loop seam is continuous.
const Duration camLoopDuration = Duration(milliseconds: 4000);

/// Evaluates the mascot at [elapsed]. Deterministic: the same inputs
/// always produce the same frame (golden/unit-test friendly).
CamFrame evaluateCamFrame(Duration elapsed, CamMode mode) {
  // Mode does not change the breathing: the character must look
  // identical on every screen, and the sheet faces already differ.
  final int loopMs = camLoopDuration.inMilliseconds;
  int t = elapsed.inMilliseconds % loopMs;
  if (t < 0) t += loopMs;
  final double td = t.toDouble();

  // Breathing: one full cycle per 4 s, ±1.2 % around the ground line.
  final double breath = 1 + 0.012 * math.sin(2 * math.pi * td / 4000);

  return CamFrame(breath: breath);
}
