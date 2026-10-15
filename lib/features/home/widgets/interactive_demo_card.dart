import 'package:flutter/material.dart';
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
  Animation<double>? _sweepAnimation;

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

    _sweepController = AnimationController(
      vsync: this,
      duration: AppMotion.demoSweep,
    );

    // Slides smoothly to one side (revealing cleaned) and returns to center (≈1.2s total)
    _sweepAnimation = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.5, end: 0.32)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.32, end: 0.5)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_sweepController!);

    _sweepController!.addListener(() {
      if (mounted) {
        setState(() {
          _fraction = _sweepAnimation!.value;
        });
      }
    });

    _sweepController!.forward().whenComplete(() {
      _cleanupSweep();
    });
  }

  void _cancelSweep() {
    if (_sweepController != null && _sweepController!.isAnimating) {
      _sweepController!.stop();
      _cleanupSweep();
    }
  }

  void _cleanupSweep() {
    _sweepController?.dispose();
    _sweepController = null;
    _sweepAnimation = null;
  }

  @override
  void dispose() {
    _cleanupSweep();
    super.dispose();
  }

  void _updateFraction(double dx, double width) {
    _cancelSweep();
    if (width <= 0) return;
    setState(() {
      _fraction = (dx / width).clamp(0.05, 0.95);
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

                return GestureDetector(
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
                          child: Icon(Icons.photo, color: p.textTertiary),
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
                            Icons.compare_arrows_rounded,
                            size: s.iconMd,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      // "Before" tag
                      Positioned(
                        left: s.sm,
                        top: s.sm,
                        child: _tag(context, 'Original'),
                      ),
                      // "After" tag
                      Positioned(
                        right: s.sm,
                        top: s.sm,
                        child: _tag(context, 'Cleaned'),
                      ),
                    ],
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
