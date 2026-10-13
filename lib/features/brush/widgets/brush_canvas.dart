import 'dart:io';

import 'package:flutter/material.dart';

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
  });

  final String imagePath;
  final Size? imageSize;
  final List<List<Offset>> strokes;
  final double strokeDiameterImagePx;
  final void Function(Offset imagePoint) onStrokeStart;
  final void Function(Offset imagePoint) onStrokePoint;
  final VoidCallback onStrokeEnd;
  final void Function(double scale) onScaleResolved;

  @override
  State<BrushCanvas> createState() => _BrushCanvasState();
}

class _BrushCanvasState extends State<BrushCanvas> {
  Offset? _downImagePoint;

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

        return InteractiveViewer(
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
                    onPanDown: (details) =>
                        _downImagePoint = toImage(details.localPosition),
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
                      ),
                      child: SizedBox(width: band.width, height: band.height),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
