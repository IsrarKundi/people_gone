import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_motion.dart';

/// Single page-transition family for all routes (ANIMATION_RESEARCH_2026.md §3, #1):
/// fade + small slide (~300 ms, standard token); back navigation reverses it.
/// Under reduced motion, spatial movement becomes a pure fade.
class PeopleGonePageTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.linear,
        ),
        child: child,
      );
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: curve ?? AppMotion.standardCurve,
      reverseCurve: AppMotion.exitCurve,
    );

    // Subtle small slide (~4% of width) + fade
    final slide = Tween<Offset>(
      begin: const Offset(0.04, 0.0),
      end: Offset.zero,
    ).animate(curved);

    return SlideTransition(
      position: slide,
      child: FadeTransition(
        opacity: curved,
        child: child,
      ),
    );
  }
}
