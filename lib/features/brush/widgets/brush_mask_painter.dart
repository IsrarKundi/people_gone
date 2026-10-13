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
  });

  final List<List<Offset>> strokes;
  final double strokeDiameterImagePx;
  final double scale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
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
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      Offset toDisplay(Offset p) => Offset(p.dx * scale, p.dy * scale);
      if (stroke.length == 1) {
        canvas.drawCircle(toDisplay(stroke.first), diameter / 2, dotPaint);
        continue;
      }
      final path = Path()
        ..moveTo(stroke.first.dx * scale, stroke.first.dy * scale);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * scale, point.dy * scale);
      }
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant BrushMaskPainter oldDelegate) => true;
}
