import 'package:flutter/material.dart';

import '../../../core/constants/app_motion.dart';
import '../../../core/theme/theme_ext.dart';

/// Animated scan beam that sweeps vertically over the photo (5s period)
/// as an indeterminate activity signal — it claims motion, never
/// measurement (Review 05). Weight reduced per Supplement R8: a minutes-
/// long sweep has no competitor precedent, so it is dosed low. No blur
/// or heavy GPU shaders (safe on budget Android minSdk 24).
class ScanBeamOverlay extends StatefulWidget {
  const ScanBeamOverlay({super.key});

  @override
  State<ScanBeamOverlay> createState() => _ScanBeamOverlayState();
}

class _ScanBeamOverlayState extends State<ScanBeamOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.scanBeamPeriod,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disable) {
      if (_controller.isAnimating) _controller.stop();
    } else {
      if (!_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.palette.primary;
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ScanBeamPainter(
            progress: _controller.value,
            color: primary,
            isStatic: disable,
          ),
        );
      },
    );
  }
}

class _ScanBeamPainter extends CustomPainter {
  const _ScanBeamPainter({
    required this.progress,
    required this.color,
    this.isStatic = false,
  });

  final double progress;
  final Color color;
  final bool isStatic;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) return;

    final double beamCenter;
    if (isStatic) {
      beamCenter = size.height * 0.5;
    } else {
      // Scan beam travels from y = -beamHeight to y = height + beamHeight
      const beamHeight = 48.0;
      final totalDistance = size.height + beamHeight * 2;
      beamCenter = (progress * totalDistance) - beamHeight;
    }

    if (!isStatic) {
      const beamHeight = 48.0;
      final rect = Rect.fromLTWH(0, beamCenter - (beamHeight / 2), size.width, beamHeight);

      // Soft gradient glow
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.06),
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.06),
            color.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.3, 0.5, 0.7, 1.0],
        ).createShader(rect);

      canvas.drawRect(rect, paint);
    }

    // Crisp 1.5dp center beam line
    final linePaint = Paint()
      ..color = color.withValues(alpha: isStatic ? 0.45 : 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, beamCenter),
      Offset(size.width, beamCenter),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_ScanBeamPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.isStatic != isStatic;
}
