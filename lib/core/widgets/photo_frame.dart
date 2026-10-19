import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';

/// The one frame for photo surfaces (audit 2026-10-19, feel research):
/// the photo is clipped at [AppSizes.photoRadius] inside a 1px
/// hairline border in the palette border colour — never a drop shadow
/// under a photo. New photo surfaces use this widget; existing ones
/// adopt the same token + hairline (History tiles, Processing hero).
class PhotoFrame extends StatelessWidget {
  const PhotoFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(s.photoRadius),
        border: Border.all(color: p.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(s.photoRadius - 1),
        child: child,
      ),
    );
  }
}
