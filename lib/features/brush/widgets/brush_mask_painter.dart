import 'package:flutter/material.dart';

/// Paints the brush strokes (stored in IMAGE pixel coordinates) into
/// the fitted photo band: points are scaled by [scale], stroke width
/// is the brush diameter in image pixels scaled the same way.
class BrushMaskPainter extends CustomPainter {
  const BrushMaskPainter({
    required this.strokes,
    required this.strokeDiameterImagePx,
    required this.scale,
    required this.color,
    this.fadingStrokes = const <List<Offset>>[],
    this.fadingOpacity = 0.0,
    this.suggestedRegion,
    this.guideColor,
    this.guideOpacity = 1.0,
  });

  final List<List<Offset>> strokes;
  final double strokeDiameterImagePx;
  final double scale;
  final Color color;

  /// Strokes undergoing undo/clear fade out (Item 14).
  final List<List<Offset>> fadingStrokes;
  final double fadingOpacity;

  /// Phase D (X14): a suggested region outline ([x1, y1, x2, y2] in
  /// image pixels) — a starting guide only; it paints nothing and
  /// is never part of the touch-up mask.
  final List<int>? suggestedRegion;
  final Color? guideColor;
  final double guideOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final region = suggestedRegion;
    if (region != null &&
        region.length == 4 &&
        guideColor != null &&
        guideOpacity > 0) {
      final rect = Rect.fromLTRB(
        region[0] * scale,
        region[1] * scale,
        region[2] * scale,
        region[3] * scale,
      );
      canvas.drawRect(
        rect,
        Paint()..color = guideColor!.withValues(alpha: 0.10 * guideOpacity),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = guideColor!.withValues(alpha: guideOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final diameter = strokeDiameterImagePx * scale;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = diameter;
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    void drawList(List<List<Offset>> list, Paint sPaint, Paint dPaint) {
      for (final stroke in list) {
        if (stroke.isEmpty) continue;
        Offset toDisplay(Offset p) => Offset(p.dx * scale, p.dy * scale);
        if (stroke.length == 1) {
          canvas.drawCircle(toDisplay(stroke.first), diameter / 2, dPaint);
          continue;
        }
        final path = Path()
          ..moveTo(stroke.first.dx * scale, stroke.first.dy * scale);
        for (final point in stroke.skip(1)) {
          path.lineTo(point.dx * scale, point.dy * scale);
        }
        canvas.drawPath(path, sPaint);
      }
    }

    drawList(strokes, strokePaint, dotPaint);

    if (fadingStrokes.isNotEmpty && fadingOpacity > 0) {
      final fadeStrokePaint = Paint()
        ..color = color.withValues(
          alpha: (color.a * fadingOpacity).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = diameter;
      final fadeDotPaint = Paint()
        ..color = color.withValues(
          alpha: (color.a * fadingOpacity).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.fill;
      drawList(fadingStrokes, fadeStrokePaint, fadeDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BrushMaskPainter oldDelegate) => true;
}
