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
/// Features:
/// 1. Natural Drift Pacing: light glide glides with an ease-in-out curve across
///    the photo and rests off-screen for ~0.8s between passes.
/// 2. Dual-Density Caustic: layered wide ambient bloom + concentrated soft
///    specular core to mimic light refracting through frosted glass.
/// 3. Museum Matte Rim: a delicate 0.75dp bevel highlight with soft depth shadow
///    grounding the 98.5% scale as an intentional art mount.
/// 4. Micro Breathing Ambient Luma: gentle 3.8s sinusoidal ambient oscillation.
/// 5. Interactive Touch-the-Glass Specular Tilt: touching/dragging on the photo
///    magnetically bends the specular light towards your finger; springs back
///    calmly upon release.
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
  late final AnimationController _touchController;

  Offset? _touchOffset;

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
    _touchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
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
      _touchController.stop();
      _touchController.value = 0.0;
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
    _touchController.stop();
    _touchController.value = 0.0;
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
        if (_touchController.isAnimating) _touchController.stop();
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
    _touchController.dispose();
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
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (disable) return;
                setState(() => _touchOffset = event.localPosition);
                _touchController.forward();
              },
              onPointerMove: (event) {
                if (disable) return;
                setState(() => _touchOffset = event.localPosition);
              },
              onPointerUp: (_) {
                if (disable) return;
                _touchController.reverse();
              },
              onPointerCancel: (_) {
                if (disable) return;
                _touchController.reverse();
              },
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
                            color: Colors.black.withValues(
                              alpha: 0.12 * progress,
                            ),
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

                      // Diagonal light glide band: dual-density soft caustic + touch tracking
                      if (widget.isWorking && !disable && progress > 0)
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: Listenable.merge(<Listenable>[
                                _glideController,
                                _touchController,
                              ]),
                              builder: (context, _) {
                                return CustomPaint(
                                  painter: _MatteLightGlidePainter(
                                    progress: _glideController.value,
                                    opacity: progress,
                                    touchOffset: _touchOffset,
                                    touchWeight: Curves.easeOutCubic.transform(
                                      _touchController.value,
                                    ),
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
    this.touchOffset,
    this.touchWeight = 0.0,
  });

  final double progress;
  final double opacity;
  final Offset? touchOffset;
  final double touchWeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || opacity <= 0) return;

    // Default glide angle: ~25 degrees diagonal
    var angle = 25.0 * math.pi / 180.0;

    // Subtly tilt angle towards finger when interacting
    if (touchWeight > 0.001 && touchOffset != null) {
      final tiltNormalizedX =
          ((touchOffset!.dx - (size.width / 2)) / (size.width / 2)).clamp(
            -1.0,
            1.0,
          );
      angle += tiltNormalizedX * 0.12 * touchWeight;
    }

    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    final totalSpan = size.width * cosA + size.height * sinA;

    // 1. Autonomous Progress & Drift Pacing:
    const activeFraction = 0.76;
    final bool isResting = progress >= activeFraction;
    final double easedProgress;
    if (isResting) {
      easedProgress = 1.0;
    } else {
      final normalized = progress / activeFraction;
      easedProgress = Curves.easeInOutCubic.transform(normalized);
    }

    // If resting and not touching, skip painting
    if (isResting && touchWeight <= 0.001) return;

    // Compute target center from finger touch or autonomous glide
    final autoTravel = totalSpan + (totalSpan * 0.56);
    double targetCenter = -(totalSpan * 0.28) + (easedProgress * autoTravel);
    if (touchOffset != null && touchWeight > 0.001) {
      final touchProjection = touchOffset!.dx * cosA + touchOffset!.dy * sinA;
      targetCenter = ui.lerpDouble(targetCenter, touchProjection, touchWeight)!;
    }

    // Subtle tactile boost when touched
    final interactionBoost = 1.0 + (0.25 * touchWeight);

    // 2. Dual-Density Soft Caustic:
    // Pass 1: Wide, atmospheric ambient bloom (~56% of total span)
    final bloomHalfWidth = math.max(110.0, totalSpan * 0.28);
    final bloomStart = Offset(
      (targetCenter - bloomHalfWidth) * cosA,
      (targetCenter - bloomHalfWidth) * sinA,
    );
    final bloomEnd = Offset(
      (targetCenter + bloomHalfWidth) * cosA,
      (targetCenter + bloomHalfWidth) * sinA,
    );

    final bloomAlpha = 0.045 * opacity * interactionBoost;
    final bloomPaint = Paint()
      ..shader = ui.Gradient.linear(
        bloomStart,
        bloomEnd,
        <Color>[
          const Color(0x00FFFFFF),
          const Color(0xFFFFD180).withValues(alpha: bloomAlpha * 0.35),
          const Color(0xFFFFF8E1).withValues(alpha: bloomAlpha * 0.70),
          Colors.white.withValues(alpha: bloomAlpha),
          const Color(0xFFE1F5FE).withValues(alpha: bloomAlpha * 0.70),
          const Color(0xFF80D8FF).withValues(alpha: bloomAlpha * 0.35),
          const Color(0x00FFFFFF),
        ],
        const <double>[0.0, 0.20, 0.38, 0.50, 0.62, 0.80, 1.0],
      );

    canvas.drawRect(Offset.zero & size, bloomPaint);

    // Pass 2: Feathered specular core (~26% of span) with subtle iridescent refraction
    final coreHalfWidth = math.max(55.0, totalSpan * 0.13);
    final coreStart = Offset(
      (targetCenter - coreHalfWidth) * cosA,
      (targetCenter - coreHalfWidth) * sinA,
    );
    final coreEnd = Offset(
      (targetCenter + coreHalfWidth) * cosA,
      (targetCenter + coreHalfWidth) * sinA,
    );

    final coreAlpha = 0.09 * opacity * interactionBoost;
    final corePaint = Paint()
      ..shader = ui.Gradient.linear(
        coreStart,
        coreEnd,
        <Color>[
          const Color(0x00FFFFFF),
          const Color(0xFFFFE082).withValues(alpha: coreAlpha * 0.30),
          const Color(0xFFFFFDE7).withValues(alpha: coreAlpha * 0.65),
          Colors.white.withValues(alpha: coreAlpha),
          const Color(0xFFEDE7F6).withValues(alpha: coreAlpha * 0.65),
          const Color(0xFFB388FF).withValues(alpha: coreAlpha * 0.30),
          const Color(0x00FFFFFF),
        ],
        const <double>[0.0, 0.20, 0.38, 0.50, 0.62, 0.80, 1.0],
      );

    canvas.drawRect(Offset.zero & size, corePaint);
  }

  @override
  bool shouldRepaint(_MatteLightGlidePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.opacity != opacity ||
      oldDelegate.touchOffset != touchOffset ||
      oldDelegate.touchWeight != touchWeight;
}
