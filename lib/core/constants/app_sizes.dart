/// Layout tokens — the ONLY file with layout magic numbers
/// (FOLDER_STRUCTURE_AND_CONVENTIONS.md §6.3). Fixed logical pixels;
/// `flutter_screenutil` and percentage sizing are forbidden (§6.4).
abstract final class AppSizes {
  // Spacing scale (4-base).
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 48;

  /// Screen padding at the compact breakpoint; [screenPaddingWide] at
  /// medium and up (§6.3).
  static const double screenPadding = 16;
  static const double screenPaddingWide = 20;
  static const double cardPadding = 16;

  // Radius.
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusSheet = 28;
  static const double radiusPill = 999;

  // Control heights.
  static const double buttonPrimary = 52;
  static const double buttonSecondary = 48;
  static const double buttonCompact = 40;
  static const double input = 52;
  static const double listRowMin = 56;
  static const double appBar = 56;

  // Icon sizes.
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 28;

  /// Minimum touch target everywhere (§6.3).
  static const double minTouchTarget = 48;

  // Breakpoints (Material window classes, §6.3).
  static const double breakpointMedium = 600;
  static const double breakpointExpanded = 840;

  /// Content is centred and capped at this width (§6.3).
  static const double contentMaxWidth = 640;

  // Motion durations in milliseconds (§6.3).
  static const int motionFastMs = 120;
  static const int motionNormalMs = 200;
  static const int motionSlowMs = 320;

  /// Screen padding for a given window width.
  static double paddingFor(double width) =>
      width >= breakpointMedium ? screenPaddingWide : screenPadding;
}
