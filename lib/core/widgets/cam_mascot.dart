import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';
import 'cam_frame.dart';
import 'cam_painter.dart';

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
class CamMascot extends StatefulWidget {
  const CamMascot({super.key, required this.mode});

  final CamMode mode;

  @override
  State<CamMascot> createState() => _CamMascotState();
}

class _CamMascotState extends State<CamMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: camLoopDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion) {
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
    if (_reduceMotion) {
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
