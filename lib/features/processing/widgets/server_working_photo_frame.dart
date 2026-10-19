import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/app_motion.dart';

/// Server-working waiting stage photo canvas (FR-13, §6):
/// When the server-working stage begins, the photo smoothly softens into an
/// even frosted blur over 400 ms and settles slightly smaller in its frame
/// (98.5% scale), like a photo placed under museum matte glass.
///
/// Refinements:
/// 1. Natural Drift Pacing: light glide glides with an ease-in-out curve across
///    the photo and rests off-screen for ~0.8s between passes.
/// 2. Dual-Density Caustic: layered wide ambient bloom + concentrated soft
///    specular core to mimic light refracting through frosted glass.
/// 3. Museum Matte Rim: a delicate 0.75dp bevel highlight with soft depth shadow
///    grounding the 98.5% scale as an intentional art mount.
/// 4. Micro Breathing Ambient Luma: gentle 3.8s sinusoidal ambient oscillation
///    keeping the glass organically alive during minute-long waits.
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
  late final AnimationController _breatheController;

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
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
  }

  void _startAnimations() {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable) {
      _settleController.value = 1.0;
      _glideController.stop();
      _glideController.value = 0.0;
      _breatheController.stop();
      _breatheController.value = 0.0;
    } else {
      _settleController.forward();
      _glideController.repeat();
      _breatheController.repeat(reverse: true);
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
    _breatheController.stop();
    _breatheController.value = 0.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.isWorking) {
      if (disable) {
        _settleController.value = 1.0;
        if (_glideController.isAnimating) _glideController.stop();
        if (_breatheController.isAnimating) _breatheController.stop();
      } else {
        if (!_settleController.isCompleted && !_settleController.isAnimating) {
          _settleController.forward();
        }
        if (!_glideController.isAnimating) {
          _glideController.repeat();
        }
        if (!_breatheController.isAnimating) {
          _breatheController.repeat(reverse: true);
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
    _breatheController.dispose();
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
              : AppMotion.enterCurve.transform(_settleController.value);

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
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.09 * progress),
                  width: 0.75,
                ),
                boxShadow: progress > 0
                    ? <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12 * progress),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1.25),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    // Photo layer: isolated in RepaintBoundary so ImageFilter is
                    // not re-rasterized on every tick of the light glide or breathe loop.
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

                    // Organic breathing frosted scrim overlay
                    if (progress > 0)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _breatheController,
                          builder: (context, _) {
                            final breatheFactor = disable
                                ? 0.0
                                : Curves.easeInOut.transform(
                                    _breatheController.value,
                                  );
                            final frostedAlpha =
                                (0.025 + (0.015 * breatheFactor)) * progress;
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: frostedAlpha,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // Diagonal light glide band: dual-density soft caustic with drift & rest
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
              ),
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

    // 1. Natural Drift Pacing:
    // Glides actively during 0.0 -> 0.76 of period with easeInOut,
    // rests offscreen during 0.76 -> 1.0 (~0.84s pause).
    const activeFraction = 0.76;
    if (progress >= activeFraction) {
      // Rest period: band has completely exited past the bottom-right edge
      return;
    }
    final normalized = progress / activeFraction;
    final easedProgress = Curves.easeInOutCubic.transform(normalized);

    // 2. Dual-Density Soft Caustic:
    // Pass 1: Wide, atmospheric ambient bloom (~56% of total span)
    final bloomHalfWidth = math.max(110.0, totalSpan * 0.28);
    final bloomTravel = totalSpan + (bloomHalfWidth * 2);
    final bloomCenter = -bloomHalfWidth + (easedProgress * bloomTravel);

    final bloomStart = Offset(
      (bloomCenter - bloomHalfWidth) * cosA,
      (bloomCenter - bloomHalfWidth) * sinA,
    );
    final bloomEnd = Offset(
      (bloomCenter + bloomHalfWidth) * cosA,
      (bloomCenter + bloomHalfWidth) * sinA,
    );

    final bloomAlpha = 0.045 * opacity;
    final bloomPaint = Paint()
      ..shader = ui.Gradient.linear(
        bloomStart,
        bloomEnd,
        <Color>[
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: bloomAlpha * 0.20),
          Colors.white.withValues(alpha: bloomAlpha * 0.65),
          Colors.white.withValues(alpha: bloomAlpha),
          Colors.white.withValues(alpha: bloomAlpha * 0.65),
          Colors.white.withValues(alpha: bloomAlpha * 0.20),
          Colors.white.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.20, 0.38, 0.50, 0.62, 0.80, 1.0],
      );

    canvas.drawRect(Offset.zero & size, bloomPaint);

    // Pass 2: Feathered specular core (~26% of span)
    final coreHalfWidth = math.max(55.0, totalSpan * 0.13);
    final coreTravel = totalSpan + (coreHalfWidth * 2);
    final coreCenter = -coreHalfWidth + (easedProgress * coreTravel);

    final coreStart = Offset(
      (coreCenter - coreHalfWidth) * cosA,
      (coreCenter - coreHalfWidth) * sinA,
    );
    final coreEnd = Offset(
      (coreCenter + coreHalfWidth) * cosA,
      (coreCenter + coreHalfWidth) * sinA,
    );

    final coreAlpha = 0.09 * opacity;
    final corePaint = Paint()
      ..shader = ui.Gradient.linear(
        coreStart,
        coreEnd,
        <Color>[
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: coreAlpha * 0.18),
          Colors.white.withValues(alpha: coreAlpha * 0.60),
          Colors.white.withValues(alpha: coreAlpha),
          Colors.white.withValues(alpha: coreAlpha * 0.60),
          Colors.white.withValues(alpha: coreAlpha * 0.18),
          Colors.white.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.20, 0.38, 0.50, 0.62, 0.80, 1.0],
      );

    canvas.drawRect(Offset.zero & size, corePaint);
  }

  @override
  bool shouldRepaint(_MatteLightGlidePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.opacity != opacity;
}
