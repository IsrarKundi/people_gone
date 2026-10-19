import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Floating magnifier loupe that tracks above the finger during brushing (G2.3).
class BrushLoupe extends StatelessWidget {
  const BrushLoupe({
    super.key,
    required this.image,
    required this.imagePoint,
    required this.strokeDiameterImagePx,
    required this.overlayColor,
    required this.touchPosition,
    required this.containerSize,
    this.diameter = 120.0,
  });

  final ui.Image image;
  final Offset imagePoint;
  final double strokeDiameterImagePx;
  final Color overlayColor;
  final Offset touchPosition;
  final Size containerSize;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    const offsetAboveFinger = 80.0;
    var targetTop = touchPosition.dy - offsetAboveFinger - diameter;
    if (targetTop < 10) {
      targetTop = touchPosition.dy + 40;
    }

    final loupeLeft = (touchPosition.dx - diameter / 2).clamp(
      10.0,
      math.max(10.0, containerSize.width - diameter - 10.0),
    ).toDouble();
    final loupeTop = targetTop.clamp(
      10.0,
      math.max(10.0, containerSize.height - diameter - 10.0),
    ).toDouble();

    return Positioned(
      left: loupeLeft,
      top: loupeTop,
      child: IgnorePointer(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black38,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: CustomPaint(
              size: Size(diameter, diameter),
              painter: _LoupePainter(
                image: image,
                imagePoint: imagePoint,
                strokeDiameterImagePx: strokeDiameterImagePx,
                overlayColor: overlayColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoupePainter extends CustomPainter {
  const _LoupePainter({
    required this.image,
    required this.imagePoint,
    required this.strokeDiameterImagePx,
    required this.overlayColor,
  });

  final ui.Image image;
  final Offset imagePoint;
  final double strokeDiameterImagePx;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    const magnification = 2.0;
    final srcWidth = size.width / magnification;
    final srcHeight = size.height / magnification;

    final srcLeft = (imagePoint.dx - srcWidth / 2)
        .clamp(0.0, math.max(0.0, image.width.toDouble() - srcWidth))
        .toDouble();
    final srcTop = (imagePoint.dy - srcHeight / 2)
        .clamp(0.0, math.max(0.0, image.height.toDouble() - srcHeight))
        .toDouble();
    final srcRect = Rect.fromLTWH(srcLeft, srcTop, srcWidth, srcHeight);
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.medium,
    );

    final center = Offset(size.width / 2, size.height / 2);
    final brushRadiusOnLoupe = (strokeDiameterImagePx / 2) * magnification;

    final brushPaint = Paint()
      ..color = overlayColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, brushRadiusOnLoupe, brushPaint);
    canvas.drawCircle(center, brushRadiusOnLoupe, strokePaint);

    final crossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - 4, center.dy),
      Offset(center.dx + 4, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 4),
      Offset(center.dx, center.dy + 4),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoupePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.imagePoint != imagePoint ||
        oldDelegate.strokeDiameterImagePx != strokeDiameterImagePx;
  }
}
