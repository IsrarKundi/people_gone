import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';
import 'cam_frame.dart';
import 'cam_painter.dart';

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

/// Cam, the Uncrowd mascot (ADR docs/architecture/cam-mascot.md).
///
/// One widget, three modes — [CamMode.avatar] for the Home header,
/// [CamMode.peek] for Processing, [CamMode.presenter] for the Paywall —
/// all rendering the same rig ([CamPainter] + [evaluateCamFrame]), so
/// the character is identical on every screen by construction.
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

  Size _box(BuildContext context) {
    final s = context.sizes;
    return switch (widget.mode) {
      CamMode.avatar => Size.square(s.mascotAvatarSize),
      // The character canvas is square; exactly half of it is visible.
      CamMode.peek => Size(s.mascotPeekHeight / 2, s.mascotPeekHeight),
      CamMode.presenter => Size.square(s.mascotPresenterHeight),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final box = _box(context);
    if (_frozen) {
      return ExcludeSemantics(
        child: CustomPaint(
          size: box,
          painter: CamPainter(
            palette: palette,
            frame: CamFrame.neutral,
            mode: widget.mode,
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _loop,
        builder: (context, _) {
          final elapsed = Duration(
            milliseconds: (_loop.value * camLoopDuration.inMilliseconds)
                .round(),
          );
          return CustomPaint(
            size: box,
            painter: CamPainter(
              palette: palette,
              frame: evaluateCamFrame(elapsed, widget.mode),
              mode: widget.mode,
            ),
          );
        },
      ),
    );
  }
}
