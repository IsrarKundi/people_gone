import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_motion.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/photo_surface.dart';
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
  AnimationController? _strokeFadeController;
  List<List<Offset>> _fadingStrokes = <List<Offset>>[];
  AnimationController? _guideController;

  @override
  void initState() {
    super.initState();
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

  @override
  void didUpdateWidget(BrushCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
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

        final viewer = InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          panEnabled: false,
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
                      _fadingStrokes.clear();
                      _strokeFadeController?.stop();
                      _downImagePoint = toImage(details.localPosition);
                    },
                    onPanStart: (details) => widget.onStrokeStart(
                      _downImagePoint ?? toImage(details.localPosition),
                    ),
                    onPanUpdate: (details) =>
                        widget.onStrokePoint(toImage(details.localPosition)),
                    onPanEnd: (_) {
                      _downImagePoint = null;
                      widget.onStrokeEnd();
                    },
                    onPanCancel: () {
                      _downImagePoint = null;
                      widget.onStrokeEnd();
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
          ],
        );
      },
    );
  }
}
