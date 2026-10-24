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

  /// First-run delay before starting the demo card sweep on Home (≈400 ms)
  /// so the eye finds the card first (first-run choreography brief §2 Beat 1).
  static const Duration firstRunSweepDelay = Duration(milliseconds: 400);


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

  /// Splash hold before advancing to Home: the animation choreography
  /// (≈1.67 s Lottie) plus settle before advancing to Home.
  static const Duration splashHold = Duration(milliseconds: 1400);

  /// Critically damped spring (damping ratio 1.0 — NO overshoot) for
  /// touch-driven motion that animates toward a target: the calm rule
  /// expressed as physics instead of a fixed-duration curve (audit
  /// 2026-10-19). Used with AnimationController.animateWith.
  static const SpringDescription springCalm = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 40,
  );

  /// The ONE permitted settle exception (ratio ≈0.85, a hint of life
  /// at the emotional peak): the Result reveal only.
  static const SpringDescription springSettle = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 34,
  );

  /// Frosted blur entrance duration on Processing (≈400 ms).
  static const Duration frostedBlurEntrance = Duration(milliseconds: 400);

  /// Waiting light glide period across the frosted photo on Processing (≈3.5 s).
  static const Duration matteLightGlidePeriod = Duration(milliseconds: 3500);

  /// Calm standard curves with NO visible overshoot.
  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutCubic;
}
