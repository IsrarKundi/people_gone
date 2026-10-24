import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cam_art.dart';
import 'cam_frame.dart';
import 'cam_video.dart';

/// True only inside `flutter test` (the runner sets FLUTTER_TEST).
/// Cam's idle loop repeats forever by design, which would block
/// `pumpAndSettle` in ANY test that renders a screen containing him —
/// so in tests he renders the neutral still frame instead, and the
/// motion itself is verified through the pure [evaluateCamFrame]
/// unit tests. Production never sets FLUTTER_TEST: behaviour there
/// is untouched.
final bool _inTestEnvironment = Platform.environment.containsKey(
  'FLUTTER_TEST',
);

/// Cam, the Uncrowd mascot.
///
/// One widget, five modes following the owner's journey — [CamMode.avatar]
/// for the Home header, [CamMode.analyzing] centred whole on the
/// Analyzing screen, [CamMode.processing] centred whole on the
/// Processing screen, [CamMode.resultsReady] back in the top-right
/// circle on Result, and [CamMode.avatarSmall] for Review / Brush /
/// History headers — all playing the owner's approved videos
/// ([CamMascotVideo]): Home circles wave, both work screens scan.
/// The circle is drawn in code, never baked into the video;
/// Analyzing and Processing are never cropped. The two videos
/// are the whole live method now — the code puppet
/// ([CamMascotArt] + [evaluateCamFrame]) survives only as the
/// still artwork for tests, reduced motion, and video loading.
///
/// Two one-shot reactions sit on top of the videos, both calm and
/// both over in under a second:
///
/// * [arrive]: the Result arrival pulse — a slow scale pulse and a
///   small tilt, played once when the widget first appears.
/// * [reactionKey]: Review's nod — changing the key (for example
///   when the user toggles a person) plays a tiny downward nod.
///
/// [concerned] has no separate video: failure screens play the
/// same scanning video. A sorry video is open work if the owner
/// wants one.
///
/// Cam is decoration, not information: he carries no action and no
/// meaning a screen-reader user would miss, so he is excluded from
/// semantics. With the system's reduced-motion setting on, he never
/// animates — the still frame renders instead (plan §4). The same
/// still frame renders under `flutter test` (see [_inTestEnvironment])
/// so host screens stay settle-able in tests.
class CamMascot extends StatefulWidget {
  const CamMascot({
    super.key,
    required this.mode,
    this.concerned = false,
    this.arrive = false,
    this.reactionKey,
  });

  final CamMode mode;

  /// Sorry, drooped idle loop for failure screens.
  final bool concerned;

  /// Play the one-shot arrival pulse on first appearance.
  final bool arrive;

  /// Changing this value plays the one-shot nod.
  final int? reactionKey;

  @override
  State<CamMascot> createState() => _CamMascotState();
}

class _CamMascotState extends State<CamMascot> with TickerProviderStateMixin {
  late final AnimationController _loop;
  late final AnimationController _reaction;
  late final AnimationController _arrive;

  /// Still-frame mode: reduced motion, or the test environment.
  bool _frozen = false;
  bool _arriveStarted = false;
  int? _lastReactionKey;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: camLoopDuration);
    _reaction = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _arrive = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _lastReactionKey = widget.reactionKey;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _frozen = reduceMotion || _inTestEnvironment;
    if (_frozen) {
      _loop.stop();
      _reaction.stop();
      _arrive.stop();
    } else {
      if (!_loop.isAnimating) _loop.repeat();
      if (widget.arrive && !_arriveStarted) {
        _arriveStarted = true;
        _arrive.forward();
      }
    }
  }

  @override
  void didUpdateWidget(CamMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reactionKey != _lastReactionKey) {
      _lastReactionKey = widget.reactionKey;
      if (!_frozen) _reaction.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _reaction.dispose();
    _arrive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_frozen) {
      return CamMascotArt(
        frame: evaluateCamFrame(
          Duration.zero,
          widget.mode,
          concerned: widget.concerned,
        ),
        mode: widget.mode,
      );
    }
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_loop, _reaction, _arrive]),
      builder: (context, _) {
        // Nod: a 2 dp dip and back, over 300 ms. After it finishes
        // the sine returns to 0, so no reset is needed.
        final double nod = 2 * math.sin(math.pi * _reaction.value);
        // Arrival pulse: a slow 3 % scale pulse and a small tilt,
        // once, over 600 ms.
        final double pulse = math.sin(math.pi * _arrive.value);
        // The idle loop ticker still runs so the one-shots above
        // have a clock, but the video carries the idle motion
        // itself — no frame is evaluated for it anymore.
        return CamMascotVideo(
          mode: widget.mode,
          nod: nod,
          pulse: pulse,
        );
      },
    );
  }
}
