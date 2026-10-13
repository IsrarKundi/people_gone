import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale — the ONLY place font sizes/weights are defined
/// (FOLDER_STRUCTURE_AND_CONVENTIONS.md §6.2). Styles are functions of the
/// active [AppPalette]: a style never hard-codes a colour outside the palette.
/// Bundled `Inter` is the Latin family; Urdu families join when localisation
/// lands (no view changes needed then — §6.2).
class AppTextStyles {
  const AppTextStyles(this.palette);

  final AppPalette palette;

  static const String _family = 'Inter';

  TextStyle _base({
    required double size,
    required FontWeight weight,
    required double lineHeight,
    Color? color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: _family,
      fontSize: size,
      fontWeight: weight,
      height: lineHeight,
      letterSpacing: letterSpacing,
      color: color ?? palette.textPrimary,
    );
  }

  TextStyle get display => _base(size: 32, weight: FontWeight.w700, lineHeight: 1.20);
  TextStyle get headlineLg => _base(size: 24, weight: FontWeight.w700, lineHeight: 1.25);
  TextStyle get headlineMd => _base(size: 20, weight: FontWeight.w600, lineHeight: 1.30);
  TextStyle get titleLg => _base(size: 18, weight: FontWeight.w600, lineHeight: 1.35);
  TextStyle get titleMd => _base(size: 16, weight: FontWeight.w600, lineHeight: 1.40);
  TextStyle get bodyLg => _base(size: 16, weight: FontWeight.w400, lineHeight: 1.50);
  TextStyle get bodyMd => _base(size: 14, weight: FontWeight.w400, lineHeight: 1.50);
  TextStyle get bodySm => _base(size: 13, weight: FontWeight.w400, lineHeight: 1.45);
  TextStyle get labelLg => _base(size: 14, weight: FontWeight.w600, lineHeight: 1.40);
  TextStyle get labelMd => _base(size: 12, weight: FontWeight.w600, lineHeight: 1.35);
  TextStyle get caption => _base(
        size: 12,
        weight: FontWeight.w400,
        lineHeight: 1.40,
        color: palette.textSecondary,
      );
  TextStyle get overline => _base(
        size: 11,
        weight: FontWeight.w600,
        lineHeight: 1.30,
        letterSpacing: 0.8,
        color: palette.textSecondary,
      );
}
