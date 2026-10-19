import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../../../core/constants/app_icons.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_motion.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';

/// An interactive before/after split slider demonstrating real output of the
/// PeopleGone pipeline (landmark photo with pedestrians cleanly removed).
/// Gives first-time users immediate proof of value without making an upload.
class InteractiveDemoCard extends StatefulWidget {
  const InteractiveDemoCard({super.key});

  /// Whether the teaching sweep has already executed in this session.
  @visibleForTesting
  static bool hasRunTeachingSweep = false;

  @override
  State<InteractiveDemoCard> createState() => _InteractiveDemoCardState();
}

class _InteractiveDemoCardState extends State<InteractiveDemoCard>
    with SingleTickerProviderStateMixin {
  double _fraction = 0.5;
  AnimationController? _sweepController;
  int _sweepRun = 0;

  @override
  void initState() {
    super.initState();
    if (!InteractiveDemoCard.hasRunTeachingSweep) {
      InteractiveDemoCard.hasRunTeachingSweep = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startTeachingSweep();
      });
    }
  }

  void _startTeachingSweep() {
    if (!mounted) return;
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable) return;

    // Unbounded controller: the teaching sweep is driven by the
    // critically damped spring (AppMotion.springCalm), not a
    // fixed-duration tween sequence (audit 2026-10-19, Task 3).
    _sweepController = AnimationController(vsync: this, value: 0.5);
    _sweepController!.addListener(() {
      if (mounted) {
        setState(() => _fraction = _sweepController!.value);
      }
    });

    unawaited(_runSweep());
  }

  /// Out to 0.32 (revealing cleaned) and back to centre (0.5), both legs on the calm spring.
  /// User input cancels the run.
  Future<void> _runSweep() async {
    final controller = _sweepController;
    if (controller == null) return;
    final run = ++_sweepRun;
    await controller.animateWith(
      SpringSimulation(AppMotion.springCalm, 0.5, 0.32, 0),
    );
    if (!mounted || run != _sweepRun) return;
    await controller.animateWith(
      SpringSimulation(AppMotion.springCalm, 0.32, 0.5, 0),
    );
    if (!mounted || run != _sweepRun) return;
    _cleanupSweep();
  }

  void _cancelSweep() {
    _sweepRun++;
    if (_sweepController?.isAnimating ?? false) {
      _sweepController?.stop();
    }
    _cleanupSweep();
  }

  void _cleanupSweep() {
    _sweepController?.dispose();
    _sweepController = null;
  }

  @override
  void dispose() {
    _cancelSweep();
    super.dispose();
  }

  void _updateFraction(double dx, double width) {
    _cancelSweep();
    if (width <= 0) return;
    setState(() {
      _fraction = (dx / width).clamp(0.05, 0.95);
    });
  }

  /// TalkBack adjustment path for the demo compare (audit 2026-10-19):
  /// the gesture area is exposed as an adjustable slider.
  void _adjustFraction(double delta) {
    _cancelSweep();
    setState(() {
      _fraction = (_fraction + delta).clamp(0.05, 0.95);
    });
  }


  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(s.radiusLg),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The split view flexes to the height Home gives the hero
          // (Review 05 R2: the hero takes its adopted scale, it does
          // not sit at a fixed small aspect in a void).
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final dividerX = _fraction * width;

                return Semantics(
                  label: AppStrings.demoCompareLabel.tr,
                  value: '${(_fraction * 100).round()}%',
                  increasedValue:
                      '${((_fraction + 0.1).clamp(0.05, 0.95) * 100).round()}%',
                  decreasedValue:
                      '${((_fraction - 0.1).clamp(0.05, 0.95) * 100).round()}%',
                  onIncrease: () => _adjustFraction(0.1),
                  onDecrease: () => _adjustFraction(-0.1),
                  child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragDown: (_) => _cancelSweep(),
                  onHorizontalDragUpdate: (d) =>
                      _updateFraction(d.localPosition.dx, width),
                  onTapDown: (d) => _updateFraction(d.localPosition.dx, width),

                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      // Cleaned result underneath (right side revealed)
                      Image.asset(
                        'assets/images/demo_result.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: p.surfaceVariant,
                          alignment: Alignment.center,
                          child: Icon(AppIcons.photoLibrary, color: p.textTertiary),
                        ),
                      ),
                      // Original on top, clipped by fraction (left side)
                      ClipRect(
                        clipper: _DemoFractionClip(_fraction),
                        child: Image.asset(
                          'assets/images/demo_original.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                      // Vertical divider line
                      Positioned(
                        left: dividerX - 1.5,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 3, color: Colors.white),
                      ),
                      // Center drag handle
                      Positioned(
                        left: dividerX - 20,
                        top: (height / 2) - 20,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withAlpha(60),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            AppIcons.arrowsLeftRight,
                            size: s.iconMd,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      // "Before" tag
                      Positioned(
                        left: s.sm,
                        top: s.sm,
                        child: _tag(context, AppStrings.demoTagOriginal.tr),
                      ),
                      // "After" tag
                      Positioned(
                        right: s.sm,
                        top: s.sm,
                        child: _tag(context, AppStrings.demoTagCleaned.tr),
                      ),
                    ],
                  ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
            child: Text(
              AppStrings.demoCaption.tr,
              style: context.textStyles.bodySm.copyWith(color: p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(BuildContext context, String text) {
    final p = context.palette;
    final s = context.sizes;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs),
      decoration: BoxDecoration(
        color: p.photoChromeBg,
        borderRadius: BorderRadius.circular(s.radiusSm),
      ),
      child: Text(
        text,
        style: context.textStyles.labelMd.copyWith(
          color: p.photoChromeFg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DemoFractionClip extends CustomClipper<Rect> {
  const _DemoFractionClip(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_DemoFractionClip oldClipper) =>
      oldClipper.fraction != fraction;
}
