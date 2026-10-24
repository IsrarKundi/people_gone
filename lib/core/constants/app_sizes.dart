import 'app_motion.dart';

/// Layout tokens — the ONLY place layout magic numbers live

/// (FOLDER_STRUCTURE_AND_CONVENTIONS.md §6.3). Fixed logical pixels;
/// `flutter_screenutil` and percentage sizing are forbidden (§6.4).
///
/// Accessed via `context.sizes` (see core/theme/theme_ext.dart).
class AppSizes {
  const AppSizes();

  // Spacing scale (4-base).
  final double xxs = 2;
  final double xs = 4;
  final double sm = 8;
  final double md = 12;
  final double lg = 16;
  final double xl = 20;
  final double xxl = 24;
  final double xxxl = 32;
  final double huge = 40;
  final double lottieSize = 43;
  final double giant = 48;

  /// Screen padding at the compact breakpoint; [screenPaddingWide] at
  /// medium and up (§6.3).
  final double screenPadding = 16;
  final double screenPaddingWide = 20;
  final double cardPadding = 16;

  // Radius.
  final double radiusSm = 8;
  final double radiusMd = 12;
  final double radiusLg = 16;
  final double radiusXl = 20;
  final double radiusSheet = 28;
  final double radiusPill = 999;

  /// The one radius for framed photo surfaces (audit 2026-10-19
  /// photo-frame system): every photo sits at this radius inside a
  /// 1px hairline border, never a drop shadow.
  final double photoRadius = 16;

  // Control heights.
  final double buttonPrimary = 46;
  final double buttonSecondary = 46;
  final double buttonCompact = 40;
  final double input = 52;
  final double listRowMin = 56;
  final double appBar = 56;

  // Icon sizes.
  final double iconSm = 20;
  final double iconMd = 24;
  final double iconLg = 28;

  /// Minimum touch target everywhere (§6.3).
  final double minTouchTarget = 48;

  // Cam mascot (plan §3 sizes are fixed dp per §6.4 — percentages
  // are forbidden). Avatar circles are fixed; Analyzing and
  // Processing are fixed widths, rendered whole and uncropped, so
  // their heights follow the sheet art's own aspect ratio.
  final double mascotAvatarSize = 44;
  final double mascotAvatarSmallSize = 32;
  final double mascotAnalyzingWidth = 200;
  final double mascotProcessingWidth = 240;

  // Breakpoints (Material window classes, §6.3).
  final double breakpointMedium = 600;
  final double breakpointExpanded = 840;

  /// Content is centred and capped at this width (§6.3).
  final double contentMaxWidth = 640;

  // Motion (§6.3, ANIMATION_RESEARCH_2026.md).
  final Duration motionFast = AppMotion.fast;
  final Duration motionNormal = AppMotion.standard;
  final Duration motionSlow = AppMotion.standard;

  /// Screen padding for a given window width.
  double paddingFor(double width) =>
      width >= breakpointMedium ? screenPaddingWide : screenPadding;
}
