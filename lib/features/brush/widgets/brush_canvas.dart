import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_motion.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/photo_surface.dart';
import 'brush_loupe.dart';
import 'brush_mask_painter.dart';

/// The brush photo surface (S5): the photo fitted contain and centred,
/// a mask overlay clipped to the fitted rect, and single-finger pan
/// drawing inside a pinch-zoom [InteractiveViewer] (pan disabled on
/// the viewer itself, so the gesture arena gives single-finger drags
/// to the drawing [GestureDetector]; its local positions are in child
/// coordinates, so conversion via the fitted rect holds at any zoom).
///
/// The stroke begins from the pan-DOWN position (captured in
/// [GestureDetector.onPanDown]): onPanStart's own position is only
/// known after the touch slop, which would shift every stroke's first
/// point. A pinch cancels the pan before it starts, so no stray dot
/// is ever drawn by a zoom gesture.
class BrushCanvas extends StatefulWidget {
  const BrushCanvas({
    super.key,
    required this.imagePath,
    required this.imageSize,
    required this.strokes,
    required this.strokeDiameterImagePx,
    required this.onStrokeStart,
    required this.onStrokePoint,
    required this.onStrokeEnd,
    required this.onScaleResolved,
    required this.hintVisible,
    this.suggestedRegion,
  });

  final String imagePath;
  final Size? imageSize;
  final List<List<Offset>> strokes;
  final double strokeDiameterImagePx;
  final void Function(Offset imagePoint) onStrokeStart;
  final void Function(Offset imagePoint) onStrokePoint;
  final VoidCallback onStrokeEnd;
  final void Function(double scale) onScaleResolved;

  /// The hint chip shows until the first stroke lands (Review 07 B2).
  final bool hintVisible;

  /// Phase D (X14): when a reflection region was suggested from the
  /// Result screen, the canvas outlines it and the hint chip names
  /// it instead of the generic brush hint.
  final List<int>? suggestedRegion;

  @override
  State<BrushCanvas> createState() => _BrushCanvasState();
}

class _BrushCanvasState extends State<BrushCanvas>
    with TickerProviderStateMixin {
  Offset? _downImagePoint;
  Offset? _touchBandPoint;
  int _pointerCount = 0;
  ui.Image? _decodedImage;
  ImageStream? _imageStream;
  ImageStreamListener? _streamListener;
  AnimationController? _strokeFadeController;
  List<List<Offset>> _fadingStrokes = <List<Offset>>[];
  AnimationController? _guideController;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _strokeFadeController = AnimationController(
      vsync: this,
      duration: AppMotion.strokeFade,
    )..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) setState(() => _fadingStrokes.clear());
        }
      });

    if (widget.suggestedRegion != null) {
      _guideController = AnimationController(
        vsync: this,
        duration: AppMotion.guideFade,
      )..addListener(() {
          if (mounted) setState(() {});
        });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final disable =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        if (disable) {
          _guideController?.value = 1.0;
        } else {
          _guideController?.forward();
        }
      });
    }
  }

  void _loadImage() {
    final file = File(widget.imagePath);
    if (!file.existsSync()) return;
    final provider = FileImage(file);
    _imageStream = provider.resolve(ImageConfiguration.empty);
    _streamListener = ImageStreamListener((ImageInfo info, bool _) {
      if (mounted) setState(() => _decodedImage = info.image);
    });
    _imageStream!.addListener(_streamListener!);
  }

  @override
  void didUpdateWidget(BrushCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      if (_imageStream != null && _streamListener != null) {
        _imageStream!.removeListener(_streamListener!);
      }
      _loadImage();
    }
    if (oldWidget.strokes.length > widget.strokes.length) {
      final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (!disable) {
        _fadingStrokes = oldWidget.strokes.sublist(widget.strokes.length);
        _strokeFadeController?.forward(from: 0.0);
      } else {
        _fadingStrokes.clear();
      }
    }
  }

  @override
  void dispose() {
    if (_imageStream != null && _streamListener != null) {
      _imageStream!.removeListener(_streamListener!);
    }
    _strokeFadeController?.dispose();
    _guideController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final file = File(widget.imagePath);
    final size = widget.imageSize;
    if (size == null || size.isEmpty) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        final band = photoBandRect(area, size);
        final scale = band.width / size.width;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onScaleResolved(scale);
        });
        Offset toImage(Offset local) {
          return Offset(
            (local.dx / scale).clamp(0, size.width),
            (local.dy / scale).clamp(0, size.height),
          );
        }

        final viewer = Listener(
          onPointerDown: (_) {
            _pointerCount++;
            if (_pointerCount >= 2) {
              if (_downImagePoint != null) {
                _downImagePoint = null;
                widget.onStrokeEnd();
              }
              if (_touchBandPoint != null) {
                setState(() => _touchBandPoint = null);
              }
            }
          },
          onPointerUp: (_) {
            _pointerCount = math.max(0, _pointerCount - 1);
          },
          onPointerCancel: (_) {
            _pointerCount = math.max(0, _pointerCount - 1);
          },
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            panEnabled: _pointerCount >= 2,
            scaleEnabled: true,
            child: SizedBox(
              width: area.width,
              height: area.height,
              child: Stack(
                children: <Widget>[
                  Positioned.fromRect(
                    rect: band,
                    child: Image.file(
                      file,
                      fit: BoxFit.fill,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: band,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanDown: (details) {
                        if (_pointerCount >= 2) return;
                        _fadingStrokes.clear();
                        _strokeFadeController?.stop();
                        _downImagePoint = toImage(details.localPosition);
                        setState(() {
                          _touchBandPoint = details.localPosition;
                        });
                      },
                      onPanStart: (details) {
                        if (_pointerCount >= 2) return;
                        widget.onStrokeStart(
                          _downImagePoint ?? toImage(details.localPosition),
                        );
                        setState(() {
                          _touchBandPoint = details.localPosition;
                        });
                      },
                      onPanUpdate: (details) {
                        if (_pointerCount >= 2) return;
                        widget.onStrokePoint(toImage(details.localPosition));
                        setState(() {
                          _touchBandPoint = details.localPosition;
                        });
                      },
                      onPanEnd: (_) {
                        _downImagePoint = null;
                        widget.onStrokeEnd();
                        setState(() {
                          _touchBandPoint = null;
                        });
                      },
                      onPanCancel: () {
                        _downImagePoint = null;
                        widget.onStrokeEnd();
                        setState(() {
                          _touchBandPoint = null;
                        });
                      },
                      child: CustomPaint(
                        painter: BrushMaskPainter(
                          strokes: widget.strokes,
                          strokeDiameterImagePx: widget.strokeDiameterImagePx,
                          scale: scale,
                          color: p.overlayRemoved,
                          fadingStrokes: _fadingStrokes,
                          fadingOpacity: _strokeFadeController != null
                              ? (1.0 - _strokeFadeController!.value)
                                  .clamp(0.0, 1.0)
                              : 0.0,
                          suggestedRegion: widget.suggestedRegion,
                          guideColor: p.primary,
                          guideOpacity: _guideController?.value ?? 1.0,
                        ),
                        child: SizedBox(width: band.width, height: band.height),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // The hint chip anchors to the photo's FITTED rectangle
        // (Review 07 B2/D14) — inside its top edge, content-sized,
        // outside the zoom transform — and fades out for good once
        // the first stroke has landed.
        final s = context.sizes;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            viewer,
            Positioned(
              top: band.top + s.sm,
              left: band.left + s.sm,
              right: area.width - band.right + s.sm,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: widget.hintVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: s.md,
                        vertical: s.sm,
                      ),
                      decoration: BoxDecoration(
                        color: p.photoChromeBg,
                        borderRadius: BorderRadius.circular(s.radiusPill),
                      ),
                      child: Text(
                        (widget.suggestedRegion != null
                                ? AppStrings.brushReflectionGuide
                                : AppStrings.brushHint)
                            .tr,
                        style: context.textStyles.bodySm.copyWith(
                          color: p.photoChromeFg,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Floating magnifier loupe following the finger while painting (G2.3)
            if (_touchBandPoint != null && _decodedImage != null)
              _buildLoupe(
                context,
                area: area,
                band: band,
                scale: scale,
                touchLocal: _touchBandPoint!,
              ),
          ],
        );
      },
    );
  }

  Widget _buildLoupe(
    BuildContext context, {
    required Size area,
    required Rect band,
    required double scale,
    required Offset touchLocal,
  }) {
    final p = context.palette;
    final screenTouch = Offset(band.left + touchLocal.dx, band.top + touchLocal.dy);
    final imagePoint = Offset(
      (touchLocal.dx / scale).clamp(0, widget.imageSize!.width),
      (touchLocal.dy / scale).clamp(0, widget.imageSize!.height),
    );

    return BrushLoupe(
      image: _decodedImage!,
      imagePoint: imagePoint,
      strokeDiameterImagePx: widget.strokeDiameterImagePx,
      overlayColor: p.overlayRemoved,
      touchPosition: screenTouch,
      containerSize: area,
      diameter: 96.0,
    );
  }
}

