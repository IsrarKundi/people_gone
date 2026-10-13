import 'package:flutter/material.dart';

import '../../../core/theme/theme_ext.dart';

/// An interactive before/after split slider demonstrating real output of the
/// PeopleGone pipeline (landmark photo with pedestrians cleanly removed).
/// Gives first-time users immediate proof of value without making an upload.
class InteractiveDemoCard extends StatefulWidget {
  const InteractiveDemoCard({super.key});

  @override
  State<InteractiveDemoCard> createState() => _InteractiveDemoCardState();
}

class _InteractiveDemoCardState extends State<InteractiveDemoCard> {
  double _fraction = 0.5;

  void _updateFraction(double dx, double width) {
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
          AspectRatio(
            aspectRatio: 16 / 10,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final dividerX = _fraction * width;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) =>
                      _updateFraction(d.localPosition.dx, width),
                  onTapDown: (d) =>
                      _updateFraction(d.localPosition.dx, width),
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
                        child: Container(
                          width: 3,
                          color: Colors.white,
                        ),
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
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.swipe_outlined,
                  size: s.iconSm,
                  color: p.primary,
                ),
                SizedBox(width: s.xs),
                Expanded(
                  child: Text(
                    'Drag divider to preview clean · Real app output',
                    style: context.textStyles.bodySm.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ),
              ],
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
