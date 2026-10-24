import 'dart:io';

import 'package:flutter/material.dart';

import 'cam_art.dart';
import 'cam_frame.dart';

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
/// circle on Result, and [CamMode.avatarSmall] for Brush / History
/// headers — all rendering the owner's sheet drawings
/// ([CamMascotArt] + [evaluateCamFrame]), so the character is
/// identical on every screen by construction. The circle is drawn
/// in code, never baked into the art; Analyzing and Processing are
/// never cropped.
///
/// Cam is decoration, not information: he carries no action and no
/// meaning a screen-reader user would miss, so he is excluded from
/// semantics. With the system's reduced-motion setting on, he never
/// animates — the neutral still frame renders instead (plan §4).
/// The same still frame renders under `flutter test` (see
/// [_inTestEnvironment]) so host screens stay settle-able in tests.
class CamMascot extends StatefulWidget {
  const CamMascot({super.key, required this.mode});

  final CamMode mode;

  @override
  State<CamMascot> createState() => _CamMascotState();
}

class _CamMascotState extends State<CamMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  /// Still-frame mode: reduced motion, or the test environment.
  bool _frozen = false;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: camLoopDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _frozen = reduceMotion || _inTestEnvironment;
    if (_frozen) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_frozen) {
      return CamMascotArt(frame: CamFrame.neutral, mode: widget.mode);
    }
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        final elapsed = Duration(
          milliseconds: (_loop.value * camLoopDuration.inMilliseconds)
              .round(),
        );
        return CamMascotArt(
          frame: evaluateCamFrame(elapsed, widget.mode),
          mode: widget.mode,
        );
      },
    );
  }
}
