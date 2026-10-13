import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';

/// The only card container (Conventions §6.7): surface + hairline border +
/// radiusLg. Flat by default — no elevation.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return Container(
      padding: padding ?? EdgeInsets.all(s.cardPadding),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(s.radiusLg),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }
}
