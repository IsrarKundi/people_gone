import 'package:flutter/animation.dart';

/// Single motion token set (ANIMATION_RESEARCH_2026.md §1-§5, ANIMATION_EXECUTION_PROMPT.md §4).
///
/// Core rule: two durations only — fast (180 ms) for feedback/toggles,
/// standard (300 ms) for screens/sheets/reveals.
/// Easing character: calm Material curves with NO visible overshoot (never bouncy).
abstract final class AppMotion {
  /// Fast token (180 ms): press feedback, chip state settles, toggles.
  static const Duration fast = Duration(milliseconds: 180);

  /// Standard token (300 ms): page routes, sheets, reveals, dialogs.
  static const Duration standard = Duration(milliseconds: 300);

  // Named exceptions explicitly authorized by ANIMATION_RESEARCH_2026.md:
  /// Teaching sweep for Home demo card (≈1.2 s, ease in-out, once per session).
  static const Duration demoSweep = Duration(milliseconds: 1200);

  /// Result first-open Before->After dissolve (≈450 ms, once).
  static const Duration resultDissolve = Duration(milliseconds: 450);

  /// Save button "Saved" receipt hold duration (≈1.2 s).
  static const Duration saveHold = Duration(milliseconds: 1200);

  /// Result compare handle nudge (≈600 ms, once).
  static const Duration compareNudge = Duration(milliseconds: 600);

  /// Brush stroke undo / clear fade-out (≈150 ms).
  static const Duration strokeFade = Duration(milliseconds: 150);

  /// Brush reflection guide outline fade-in (≈250 ms).
  static const Duration guideFade = Duration(milliseconds: 250);

  /// History delete tile fade+scale out (≈250 ms).
  static const Duration deleteScale = Duration(milliseconds: 250);

  /// Settings theme switch crossfade (≈250 ms).
  static const Duration themeCrossfade = Duration(milliseconds: 250);

  /// Reduced-motion fallback crossfade duration (≤150 ms).
  static const Duration reducedCrossfade = Duration(milliseconds: 150);

  /// Splash entrance choreography total (logo → tagline → footer).
  static const Duration splashChoreography = Duration(milliseconds: 1000);

  /// Splash hold before advancing to Home: the choreography plus a
  /// short settle — no dead time after the animation completes
  /// (audit 2026-10-19: the old 2100 ms hold outlasted its own
  /// 1000 ms animation by over a second).
  static const Duration splashHold = Duration(milliseconds: 1200);

  /// Calm standard curves with NO visible overshoot.
  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve spring = Curves.easeOutCubic;
}
