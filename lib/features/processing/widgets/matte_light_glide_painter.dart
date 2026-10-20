import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Specification for a microscopic sunlight particle mote floating in the
/// frosted matte glass (Idea 4).
class _MoteSpec {
  const _MoteSpec({
    required this.relX,
    required this.relY,
    required this.radius,
    required this.driftPhase,
    required this.driftRadius,
    required this.tint,
  });

  final double relX;
  final double relY;
  final double radius;
  final double driftPhase;
  final double driftRadius;
  final Color tint;
}

const _kMotes = <_MoteSpec>[
  _MoteSpec(
    relX: 0.22,
    relY: 0.28,
    radius: 1.8,
    driftPhase: 0.0,
    driftRadius: 8.0,
    tint: Color(0xFFFFE082), // Warm sunlight amber
  ),
  _MoteSpec(
    relX: 0.74,
    relY: 0.24,
    radius: 1.4,
    driftPhase: 1.2,
    driftRadius: 6.0,
    tint: Color(0xFF80D8FF), // Celestial cyan
  ),
  _MoteSpec(
    relX: 0.48,
    relY: 0.52,
    radius: 2.2,
    driftPhase: 2.4,
    driftRadius: 10.0,
    tint: Colors.white, // Crisp core
  ),
  _MoteSpec(
    relX: 0.31,
    relY: 0.76,
    radius: 1.5,
    driftPhase: 3.8,
    driftRadius: 7.0,
    tint: Color(0xFFFFD180), // Soft gold
  ),
  _MoteSpec(
    relX: 0.82,
    relY: 0.72,
    radius: 1.9,
    driftPhase: 5.0,
    driftRadius: 9.0,
    tint: Color(0xFFB388FF), // Prismatic violet
  ),
];

/// Custom painter for the frosted photo matte light glide (FR-13, §6).
///
/// Features:
/// 1. Natural Drift Pacing: glides with easeInOutCubic and rests off-screen for ~0.8s.
/// 2. Dual-Density Caustic: wide atmospheric bloom + concentrated specular core.
/// 3. Prismatic Chromatic Dispersion (Idea 2): subtle warm amber leading edge and
///    celestial cyan/violet trailing edge.
/// 4. Interactive Touch Tracking (Idea 1): subtly tilts angle and pulls specular
///    core toward user finger on touch.
/// 5. Floating Sunlight Motes (Idea 4): microscopic luminescent particles dancing
///    in the sunbeam that illuminate when the light passes and repel on touch.
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

    // Compute target center from finger touch or autonomous glide
    final autoTravel = totalSpan + (totalSpan * 0.56);
    double targetCenter = -(totalSpan * 0.28) + (easedProgress * autoTravel);
    if (touchOffset != null && touchWeight > 0.001) {
      final touchProjection = touchOffset!.dx * cosA + touchOffset!.dy * sinA;
      targetCenter = ui.lerpDouble(targetCenter, touchProjection, touchWeight)!;
    }

    // Subtle tactile boost when touched
    final interactionBoost = 1.0 + (0.25 * touchWeight);

    // 2. Dual-Density Soft Caustic (Light glide band)
    final bloomHalfWidth = math.max(110.0, totalSpan * 0.28);
    final coreHalfWidth = math.max(55.0, totalSpan * 0.13);

    // Only draw the light glide beam if actively traveling or touched
    if (!isResting || touchWeight > 0.001) {
      // Pass 1: Wide, atmospheric ambient bloom (~56% of total span)
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

    // 3. Floating Sunlight Particle Motes (Idea 4)
    final haloPaint = Paint()..style = PaintingStyle.fill;
    final corePaint = Paint()..style = PaintingStyle.fill;

    for (final mote in _kMotes) {
      final baseX = mote.relX * size.width;
      final baseY = mote.relY * size.height;

      // Slow orbital drift
      final driftAngle = (progress * 2 * math.pi) + mote.driftPhase;
      final driftX = math.cos(driftAngle) * mote.driftRadius;
      final driftY = math.sin(driftAngle * 1.4) * mote.driftRadius;
      var pos = Offset(baseX + driftX, baseY + driftY);

      // Interactive repulsion from finger on touch
      if (touchOffset != null && touchWeight > 0.001) {
        final delta = pos - touchOffset!;
        final dist = delta.distance;
        if (dist < 72.0 && dist > 0.0) {
          final repel = (1.0 - (dist / 72.0)) * 22.0 * touchWeight;
          pos += (delta / dist) * repel;
        }
      }

      // Check distance from current light glide beam
      var inBeamFactor = 0.0;
      if (!isResting || touchWeight > 0.001) {
        final moteProjection = pos.dx * cosA + pos.dy * sinA;
        final distFromBeam = (moteProjection - targetCenter).abs();
        if (distFromBeam < bloomHalfWidth) {
          inBeamFactor =
              (1.0 - (distFromBeam / bloomHalfWidth)).clamp(0.0, 1.0);
        }
      }

      // Micro illumination in sunbeam
      final moteAlpha =
          (0.07 + (0.32 * inBeamFactor)) * opacity * interactionBoost;
      if (moteAlpha <= 0.005) continue;

      // Soft diffuse halo
      haloPaint.color = mote.tint.withValues(alpha: moteAlpha * 0.40);
      canvas.drawCircle(pos, mote.radius * 2.2, haloPaint);

      // Bright core speck
      corePaint.color = Colors.white.withValues(alpha: moteAlpha);
      canvas.drawCircle(pos, mote.radius, corePaint);
    }
  }

  @override
  bool shouldRepaint(MatteLightGlidePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.opacity != opacity ||
      oldDelegate.touchOffset != touchOffset ||
      oldDelegate.touchWeight != touchWeight;
}
