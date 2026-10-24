import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/app_motion.dart';
import 'matte_light_glide_painter.dart';

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
/// 3. Prismatic Chromatic Dispersion (Idea 2): physical optical caustics with
///    warm amber leading edge and celestial violet/cyan trailing edge.
/// 4. Interactive Touch-the-Glass Specular Tilt (Idea 1): touching/dragging
///    magnetically tilts the specular reflection toward your finger.
/// 5. Dynamic Ambient Canvas Bloom (Idea 3): multi-layer ambilight halo
///    radiating outward beyond frame borders, breathing and blooming in sync
///    with the light glide and shifting in 3D parallax on touch.
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

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _settleController,
        _glideController,
        _breatheController,
        _touchController,
      ]),
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

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final touchWeight = disable
            ? 0.0
            : Curves.easeOutCubic.transform(_touchController.value);

        // Parallax shift for ambilight bloom when user tilts card with touch
        var touchShiftX = 0.0;
        var touchShiftY = 0.0;
        if (touchWeight > 0.001 && _touchOffset != null) {
          final size = MediaQuery.maybeSizeOf(context);
          final refW = (size != null && size.width > 0) ? size.width : 360.0;
          final refH = (size != null && size.height > 0) ? size.height : 480.0;
          touchShiftX =
              -((_touchOffset!.dx - (refW / 2)) / (refW / 2)).clamp(-1.0, 1.0) *
              8.0 *
              touchWeight;
          touchShiftY =
              -((_touchOffset!.dy - (refH / 2)) / (refH / 2)).clamp(-1.0, 1.0) *
              6.0 *
              touchWeight;
        }

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
                        // Anchoring physical depth shadow (confined cleanly beneath the frame, no light bleeding outside)
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: (isDark ? 0.28 : 0.12) * progress,
                          ),
                          blurRadius: 16 + (4 * touchWeight),
                          offset: Offset(
                            touchShiftX * 0.4,
                            4 + (2 * touchWeight) + (touchShiftY * 0.4),
                          ),
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
                                painter: MatteLightGlidePainter(
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
    );
  }
}
