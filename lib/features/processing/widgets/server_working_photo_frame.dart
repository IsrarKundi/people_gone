import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/app_motion.dart';

/// Server-working waiting stage photo canvas (FR-13, §6):
/// When the server-working stage begins, the photo smoothly softens into an
/// even frosted blur over 400 ms and settles slightly smaller in its frame
/// (98.5% scale), like a photo placed under matte glass.
///
/// While waiting, one wide, very soft band of light glides diagonally across
/// the blurred photo every 3.5 seconds in a calm loop (no sharp edges, very
/// low opacity — a soft glow passing over glass, not a line).
///
/// Under reduced motion, the photo still blurs and settles, but the light band
/// does not move. The blurred photo is cached in a [RepaintBoundary] so only the
/// lightweight specular band repaints, ensuring locked 60/120 fps performance
/// even on budget Android devices during minute-long waits.
class ServerWorkingPhotoFrame extends StatefulWidget {
  const ServerWorkingPhotoFrame({
    super.key,
    required this.imageFile,
    required this.isWorking,
  });

  final File imageFile;
  final bool isWorking;

  @override
  State<ServerWorkingPhotoFrame> createState() =>
      _ServerWorkingPhotoFrameState();
}

class _ServerWorkingPhotoFrameState extends State<ServerWorkingPhotoFrame>
    with TickerProviderStateMixin {
  late final AnimationController _settleController;
  late final AnimationController _glideController;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(
      vsync: this,
      duration: AppMotion.frostedBlurEntrance,
    );
    _glideController = AnimationController(
      vsync: this,
      duration: AppMotion.matteLightGlidePeriod,
    );
  }

  void _startAnimations() {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable) {
      _settleController.value = 1.0;
      _glideController.stop();
      _glideController.value = 0.0;
    } else {
      _settleController.forward();
      _glideController.repeat();
    }
  }

  void _stopAnimations() {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable) {
      _settleController.value = 0.0;
    } else {
      _settleController.reverse();
    }
    _glideController.stop();
    _glideController.value = 0.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.isWorking) {
      if (disable) {
        _settleController.value = 1.0;
        if (_glideController.isAnimating) _glideController.stop();
      } else {
        if (!_settleController.isCompleted && !_settleController.isAnimating) {
          _settleController.forward();
        }
        if (!_glideController.isAnimating) {
          _glideController.repeat();
        }
      }
    }
  }

  @override
  void didUpdateWidget(ServerWorkingPhotoFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWorking != oldWidget.isWorking) {
      if (widget.isWorking) {
        _startAnimations();
      } else {
        _stopAnimations();
      }
    }
  }

  @override
  void dispose() {
    _settleController.dispose();
    _glideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return ClipRect(
      child: AnimatedBuilder(
        animation: _settleController,
        builder: (context, _) {
          final progress = disable
              ? (widget.isWorking ? 1.0 : 0.0)
              : CurvedAnimation(
                  parent: _settleController,
                  curve: AppMotion.enterCurve,
                  reverseCurve: AppMotion.exitCurve,
                ).value;

          // 1.0 -> 0.985 settle (approx 98.5% scale in frame)
          final scale = 1.0 - (0.015 * progress);
          // Even frosted blur up to 14.0 sigma across the whole photo
          final blurSigma = 14.0 * progress;

          final screenWidth = MediaQuery.maybeSizeOf(context)?.width.toInt();
          final cacheWidth = (screenWidth != null && screenWidth > 0)
              ? screenWidth
              : null;

          final photoWidget = Image.file(
            widget.imageFile,
            fit: BoxFit.contain,
            cacheWidth: cacheWidth,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );

          return Transform.scale(
            scale: scale,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Photo layer: isolated in RepaintBoundary so ImageFilter is
                // not re-rasterized on every tick of the 3.5s light glide loop.
                RepaintBoundary(
                  child: blurSigma > 0.05
                      ? ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: blurSigma,
                            sigmaY: blurSigma,
                            tileMode: TileMode.clamp,
                          ),
                          child: photoWidget,
                        )
                      : photoWidget,
                ),

                // Subtle frosted scrim to evoke the matte glass surface
                if (progress > 0)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03 * progress),
                      ),
                    ),
                  ),

                // Diagonal light glide band: wide, soft glow passing over glass.
                // Disabled / still under reduced motion.
                if (widget.isWorking && !disable && progress > 0)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _glideController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _MatteLightGlidePainter(
                              progress: _glideController.value,
                              opacity: progress,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MatteLightGlidePainter extends CustomPainter {
  const _MatteLightGlidePainter({
    required this.progress,
    required this.opacity,
  });

  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || opacity <= 0) return;

    // Glide angle: ~25 degrees diagonal
    const angle = 25.0 * math.pi / 180.0;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    // Total span along the direction vector
    final totalSpan = size.width * cosA + size.height * sinA;

    // One wide, very soft band of light (≈ 44% of total span, min 160dp)
    final bandHalfWidth = math.max(80.0, totalSpan * 0.22);
    final travelDistance = totalSpan + (bandHalfWidth * 2);

    // Center of band traverses smoothly from offscreen top-left to offscreen bottom-right
    final center = -bandHalfWidth + (progress * travelDistance);

    final start = Offset(
      (center - bandHalfWidth) * cosA,
      (center - bandHalfWidth) * sinA,
    );
    final end = Offset(
      (center + bandHalfWidth) * cosA,
      (center + bandHalfWidth) * sinA,
    );

    // Soft glow with zero sharp edge, very low peak opacity (~0.12 * opacity)
    final peakAlpha = 0.12 * opacity;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        start,
        end,
        <Color>[
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: peakAlpha * 0.18),
          Colors.white.withValues(alpha: peakAlpha * 0.60),
          Colors.white.withValues(alpha: peakAlpha),
          Colors.white.withValues(alpha: peakAlpha * 0.60),
          Colors.white.withValues(alpha: peakAlpha * 0.18),
          Colors.white.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.20, 0.38, 0.50, 0.62, 0.80, 1.0],
      );

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_MatteLightGlidePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.opacity != opacity;
}
