import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'cam_frame.dart';

/// Renders one [CamFrame] of Cam (ADR docs/architecture/cam-mascot.md).
///
/// The geometry is the single character definition shared by all three
/// modes — a 240×240 canvas identical to the shipped vector master
/// `assets/icons/ic_cam.svg` (same coordinates, same part order). Modes
/// differ only in framing: presenter fits the whole canvas, peek shows
/// its left half, avatar crops to the head inside a circle.
class CamPainter extends CustomPainter {
  const CamPainter({
    required this.palette,
    required this.frame,
    required this.mode,
  });

  final AppPalette palette;
  final CamFrame frame;
  final CamMode mode;

  static const double _canvasSize = 240;

  @override
  void paint(Canvas canvas, Size size) {
    _applyFraming(canvas, size);

    // Breathing: a barely-visible vertical scale around the ground line.
    canvas
      ..translate(120, 232)
      ..scale(1, frame.breath)
      ..translate(-120, -232);

    _drawTail(canvas);
    _drawBody(canvas);
    _drawHead(canvas);
    if (mode == CamMode.peek) _drawPeekPaw(canvas);
  }

  /// Maps the 240×240 character canvas into the widget's box per mode.
  void _applyFraming(Canvas canvas, Size size) {
    switch (mode) {
      case CamMode.presenter:
        canvas.clipRect(Offset.zero & size);
        canvas.scale(size.width / _canvasSize);
      case CamMode.peek:
        // The widget box is exactly the visible half; the canvas is
        // scaled by height and its left half shows.
        canvas.clipRect(Offset.zero & size);
        canvas.scale(size.height / _canvasSize);
      case CamMode.avatar:
        canvas.clipPath(Path()..addOval(Offset.zero & size));
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = palette.primaryContainer,
        );
        // Cover-fit the head region (canvas 44..196 × 22..158) into the
        // circle, centred on the head centre (120, 90).
        final double s = math.max(size.width / 152, size.height / 136);
        canvas
          ..translate(size.width / 2, size.height / 2)
          ..scale(s)
          ..translate(-120, -90);
    }
  }

  void _drawTail(Canvas canvas) {
    final Path path = Path();
    const double cx = 44;
    const double cy = 202;
    const double t0 = -0.05 * math.pi;
    const double t1 = t0 + 2.1 * math.pi;
    for (int i = 0; i <= 28; i++) {
      final double t = t0 + (t1 - t0) * i / 28;
      final double r = 30 - 19 * (t - t0) / (t1 - t0);
      final double x = cx + r * math.cos(t);
      final double y = cy + r * math.sin(t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final Paint under = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = palette.mascotDeep;
    final Paint over = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = palette.mascotBody;
    canvas
      ..drawPath(path, under)
      ..drawPath(path, over);
  }

  void _drawBody(Canvas canvas) {
    final Paint body = Paint()..color = palette.mascotBody;
    // Feet.
    _ellipse(canvas, 96, 226, 17, 8, body);
    _ellipse(canvas, 144, 226, 17, 8, body);
    // Body and side arms.
    _ellipse(canvas, 120, 186, 57, 44, body);
    _arm(canvas, 64, -0.35);
    _arm(canvas, 176, 0.35);
    // Belly.
    _ellipse(canvas, 120, 194, 35, 31, Paint()..color = palette.mascotBelly);
    // Soft shadow where the head meets the body.
    _ellipse(
      canvas,
      120,
      152,
      38,
      12,
      Paint()..color = palette.mascotShade.withValues(alpha: 0.45),
    );
  }

  void _arm(Canvas canvas, double cx, double rotation) {
    canvas
      ..save()
      ..translate(cx, 188)
      ..rotate(rotation);
    _ellipse(canvas, 0, 0, 11, 20, Paint()..color = palette.mascotBody);
    canvas.restore();
  }

  void _drawHead(Canvas canvas) {
    final Paint body = Paint()..color = palette.mascotBody;
    canvas
      ..save()
      ..translate(120, 148)
      ..rotate(frame.tilt)
      ..translate(-120, -148);

    // Crest bumps (silhouette), then the head base.
    canvas
      ..drawCircle(const Offset(86, 45), 14, body)
      ..drawCircle(const Offset(120, 37), 16, body)
      ..drawCircle(const Offset(154, 45), 14, body);
    _ellipse(canvas, 120, 94, 63, 55, body);

    // Soft shade low on the head, clipped to the head shape.
    canvas
      ..save()
      ..clipPath(
        Path()..addOval(
          Rect.fromCenter(
            center: const Offset(120, 94),
            width: 126,
            height: 110,
          ),
        ),
      );
    _ellipse(
      canvas,
      120,
      126,
      50,
      28,
      Paint()..color = palette.mascotShade.withValues(alpha: 0.25),
    );
    canvas.restore();

    // Muzzle, nostrils, smile.
    _ellipse(canvas, 120, 120, 35, 21, Paint()..color = palette.mascotBelly);
    final Paint nostril = Paint()
      ..color = palette.mascotDeep.withValues(alpha: 0.3);
    canvas
      ..drawCircle(const Offset(111, 110), 1.8, nostril)
      ..drawCircle(const Offset(129, 110), 1.8, nostril);
    final double halfSweep = 0.35 + (1.134 - 0.35) * frame.smile;
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(120, 114), radius: 15),
      math.pi / 2 - halfSweep,
      2 * halfSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..color = palette.mascotDeep,
    );

    _drawEye(canvas, 90);
    _drawEye(canvas, 150);
    canvas.restore();
  }

  void _drawEye(Canvas canvas, double cx) {
    const double cy = 72;
    final Paint body = Paint()..color = palette.mascotBody;
    // Turret (the blue socket), eyeball, pupil, glint.
    canvas.drawCircle(Offset(cx, cy), 24, body);
    canvas.drawCircle(
      Offset(cx, cy),
      18.5,
      Paint()..color = palette.mascotShine,
    );
    final Offset pupil = Offset(cx + frame.pupilDx, cy + frame.pupilDy);
    canvas.drawCircle(pupil, 9, Paint()..color = palette.mascotDeep);
    canvas.drawCircle(
      pupil + const Offset(-3.2, -3.2),
      2.8,
      Paint()..color = palette.mascotShine,
    );
    // Lid: the body colour sweeping down over the eyeball.
    if (frame.lid > 0) {
      canvas
        ..save()
        ..clipPath(
          Path()
            ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: 18.5)),
        );
      canvas.drawRect(
        Rect.fromLTWH(cx - 19.5, cy - 19.5, 39, frame.lid * 39),
        body,
      );
      canvas.restore();
      // The gentle closed-eye line once the blink has (nearly) landed.
      if (frame.lid > 0.8) {
        final double a = ((frame.lid - 0.8) / 0.2).clamp(0.0, 1.0) * 0.8;
        final Path line = Path()
          ..moveTo(cx - 13, cy + 1)
          ..quadraticBezierTo(cx, cy + 5.5, cx + 13, cy + 1);
        canvas.drawPath(
          line,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..color = palette.mascotDeep.withValues(alpha: a),
        );
      }
    }
  }

  /// Peek mode only: the paw gripping the screen edge, drawn at the
  /// cut line (canvas x=120 is the widget's right edge in peek mode).
  void _drawPeekPaw(Canvas canvas) {
    _ellipse(canvas, 117, 168, 9, 14, Paint()..color = palette.mascotBody);
    final Paint toe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = palette.mascotDeep.withValues(alpha: 0.45);
    canvas
      ..drawLine(const Offset(113, 161), const Offset(113, 170), toe)
      ..drawLine(const Offset(121, 161), const Offset(121, 170), toe);
  }

  void _ellipse(
    Canvas canvas,
    double cx,
    double cy,
    double rx,
    double ry,
    Paint paint,
  ) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 2 * rx, height: 2 * ry),
      paint,
    );
  }

  @override
  bool shouldRepaint(CamPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.mode != mode ||
      oldDelegate.palette != palette;
}
