import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text.dart';

/// Shortcuts so feature code reads tokens, never literals (Conventions §4.3).
extension ThemeExt on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  AppTextStyles get textStyles => AppTextStyles(palette);

  /// The layout token set.
  AppSizes get sizes => const AppSizes();
}
