import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Custom painter for the frosted photo matte light glide (FR-13, §6).
///
/// Features:
/// 1. Natural Drift Pacing: glides with easeInOutCubic and rests off-screen for ~0.8s.
/// 2. Dual-Density Caustic: wide atmospheric bloom + concentrated specular core.
/// 3. Prismatic Chromatic Dispersion: subtle warm amber leading edge and celestial
///    cyan/violet trailing edge (Idea 2).
/// 4. Interactive Touch Tracking: subtly tilts angle and pulls specular core toward
///    user finger on touch (Idea 1).
class MatteLightGlidePainter extends CustomPainter {
  const MatteLightGlidePainter({
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

    // Strictly ensure glare cannot exceed image boundary
    canvas.save();
    canvas.clipRect(Offset.zero & size);

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
    if (isResting && touchWeight <= 0.001) {
      canvas.restore();
      return;
    }

    // 2. Ultra-Wide Luminous Caustic Glare Band (doubled width):
    // - Ambient bloom: ~100% of totalSpan (at least 440px)
    // - Specular core glare: ~60% of totalSpan (at least 250px)
    final bloomHalfWidth = math.max(440.0, totalSpan * 1.0);
    final coreHalfWidth = math.max(250.0, totalSpan * 0.60);

    // Compute target center from finger touch or autonomous glide
    final autoTravel = totalSpan + (bloomHalfWidth * 2.0);
    double targetCenter = -bloomHalfWidth + (easedProgress * autoTravel);
    if (touchOffset != null && touchWeight > 0.001) {
      final touchProjection = touchOffset!.dx * cosA + touchOffset!.dy * sinA;
      targetCenter = ui.lerpDouble(targetCenter, touchProjection, touchWeight)!;
    }

    // Subtle tactile boost when touched
    final interactionBoost = 1.0 + (0.25 * touchWeight);

    // Pass 1: Wide, atmospheric ambient bloom
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

    // Pass 2: Wide specular core with chromatic dispersion
    final coreStart = Offset(
      (targetCenter - coreHalfWidth) * cosA,
      (targetCenter - coreHalfWidth) * sinA,
    );
    final coreEnd = Offset(
      (targetCenter + coreHalfWidth) * cosA,
      (targetCenter + coreHalfWidth) * sinA,
    );

    final coreAlpha = 0.10 * opacity * interactionBoost;
    final corePaint = Paint()
      ..shader = ui.Gradient.linear(
        coreStart,
        coreEnd,
        <Color>[
          const Color(0x00FFFFFF),
          const Color(0xFFFFE082).withValues(alpha: coreAlpha * 0.25),
          const Color(0xFFFFFDE7).withValues(alpha: coreAlpha * 0.60),
          Colors.white.withValues(alpha: coreAlpha * 0.92),
          Colors.white.withValues(alpha: coreAlpha),
          Colors.white.withValues(alpha: coreAlpha * 0.92),
          const Color(0xFFEDE7F6).withValues(alpha: coreAlpha * 0.60),
          const Color(0xFFB388FF).withValues(alpha: coreAlpha * 0.25),
          const Color(0x00FFFFFF),
        ],
        const <double>[0.0, 0.18, 0.32, 0.44, 0.50, 0.56, 0.68, 0.82, 1.0],
      );

    canvas.drawRect(Offset.zero & size, corePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(MatteLightGlidePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.opacity != opacity ||
      oldDelegate.touchOffset != touchOffset ||
      oldDelegate.touchWeight != touchWeight;
}
