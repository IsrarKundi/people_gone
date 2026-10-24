import 'package:flutter/material.dart';

/// Semantic colour palette — the ONLY file with `Color(0x...)` literals
/// (FOLDER_STRUCTURE_AND_CONVENTIONS.md §6.1). Values are the decided token
/// table; `photoChromeBg`/`photoChromeFg` are the Design Direction R1
/// additions for controls that sit on a photo (docs/design/DESIGN_DIRECTION.md
/// §2.2).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.error,
    required this.errorBg,
    required this.scrim,
    required this.overlayRemoved,
    required this.overlayKept,
    required this.photoChromeBg,
    required this.photoChromeFg,
    required this.mascotLid,
    required this.mascotPupil,
    required this.mascotPupilTeal,
    required this.mascotEyeWhite,
    required this.mascotRing,
    required this.mascotRingReady,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color error;
  final Color errorBg;
  final Color scrim;
  final Color overlayRemoved;
  final Color overlayKept;
  final Color photoChromeBg;
  final Color photoChromeFg;

  // Cam mascot overlay tones (ADR docs/architecture/cam-mascot.md).
  // The character itself is the F3 artwork (no vector tones any more);
  // these three colours are sampled from that artwork and used ONLY
  // for the eye overlays: lid = head blue above the eyes, pupil = the
  // near-black navy disc, eyeWhite = the sclera. Identical in both
  // themes — they are the character's own colours, not theme colours.
  final Color mascotLid;
  final Color mascotPupil;
  final Color mascotPupilTeal;
  final Color mascotEyeWhite;

  // Cam circle rings, drawn in code (sampled from the sheet art:
  // peach avatar ring, green results-ready ring). Identical in
  // both themes — they are the character's own colours.
  final Color mascotRing;
  final Color mascotRingReady;

  static const Color emerald = Color(0xFF10B981);
  static const Color crimson = Color(0xFFEF4444);

  static const AppPalette light = AppPalette(
    primary: Color(0xFF2563EB),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDBEAFE),
    secondary: Color(0xFF0F766E),
    background: Color(0xFFF8F9FA),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1F3F5),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF4B5563),
    textTertiary: Color(0xFF9CA3AF),
    border: Color(0xFFE5E7EB),
    success: Color(0xFF10B981),
    successBg: Color(0xFFD1FAE5),
    warning: Color(0xFFF59E0B),
    warningBg: Color(0xFFFEF3C7),
    error: Color(0xFFEF4444),
    errorBg: Color(0xFFFEE2E2),
    scrim: Color(0x8C0A0C10),
    overlayRemoved: Color(0x99EF4444),
    overlayKept: Color(0x9910B981),
    photoChromeBg: Color(0x990F172A),
    photoChromeFg: Color(0xFFFFFFFF),
    mascotLid: Color(0xFF1E48C1),
    mascotPupil: Color(0xFF000F3F),
    mascotPupilTeal: Color(0xFF0E5F5A),
    mascotEyeWhite: Color(0xFFFFFFFF),
    mascotRing: Color(0xFFFFAF7A),
    mascotRingReady: Color(0xFF5BAD62),
  );

  static const AppPalette dark = AppPalette(
    primary: Color(0xFF60A5FA),
    onPrimary: Color(0xFF0B132B),
    primaryContainer: Color(0xFF1E3A8A),
    secondary: Color(0xFF2DD4BF),
    background: Color(0xFF0B0D11),
    surface: Color(0xFF14171E),
    surfaceVariant: Color(0xFF1D212A),
    textPrimary: Color(0xFFF9FAFB),
    textSecondary: Color(0xFF9CA3AF),
    textTertiary: Color(0xFF6B7280),
    border: Color(0xFF252932),
    success: Color(0xFF10B981),
    successBg: Color(0xFF064E3B),
    warning: Color(0xFFFBBF24),
    warningBg: Color(0xFF451A03),
    error: Color(0xFFF87171),
    errorBg: Color(0xFF450A0A),
    scrim: Color(0xB3000000),
    overlayRemoved: Color(0x99EF4444),
    overlayKept: Color(0x9910B981),
    photoChromeBg: Color(0xB30B0D11),
    photoChromeFg: Color(0xFFFFFFFF),
    mascotLid: Color(0xFF1E48C1),
    mascotPupil: Color(0xFF000F3F),
    mascotPupilTeal: Color(0xFF0E5F5A),
    mascotEyeWhite: Color(0xFFFFFFFF),
    mascotRing: Color(0xFFFFAF7A),
    mascotRingReady: Color(0xFF5BAD62),
  );

  @override
  AppPalette copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? secondary,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? border,
    Color? success,
    Color? successBg,
    Color? warning,
    Color? warningBg,
    Color? error,
    Color? errorBg,
    Color? scrim,
    Color? overlayRemoved,
    Color? overlayKept,
    Color? photoChromeBg,
    Color? photoChromeFg,
    Color? mascotLid,
    Color? mascotPupil,
    Color? mascotPupilTeal,
    Color? mascotEyeWhite,
    Color? mascotRing,
    Color? mascotRingReady,
  }) {
    return AppPalette(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      secondary: secondary ?? this.secondary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      border: border ?? this.border,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      error: error ?? this.error,
      errorBg: errorBg ?? this.errorBg,
      scrim: scrim ?? this.scrim,
      overlayRemoved: overlayRemoved ?? this.overlayRemoved,
      overlayKept: overlayKept ?? this.overlayKept,
      photoChromeBg: photoChromeBg ?? this.photoChromeBg,
      photoChromeFg: photoChromeFg ?? this.photoChromeFg,
      mascotLid: mascotLid ?? this.mascotLid,
      mascotPupil: mascotPupil ?? this.mascotPupil,
      mascotPupilTeal: mascotPupilTeal ?? this.mascotPupilTeal,
      mascotEyeWhite: mascotEyeWhite ?? this.mascotEyeWhite,
      mascotRing: mascotRing ?? this.mascotRing,
      mascotRingReady: mascotRingReady ?? this.mascotRingReady,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primaryContainer: mix(primaryContainer, other.primaryContainer),
      secondary: mix(secondary, other.secondary),
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceVariant: mix(surfaceVariant, other.surfaceVariant),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      border: mix(border, other.border),
      success: mix(success, other.success),
      successBg: mix(successBg, other.successBg),
      warning: mix(warning, other.warning),
      warningBg: mix(warningBg, other.warningBg),
      error: mix(error, other.error),
      errorBg: mix(errorBg, other.errorBg),
      scrim: mix(scrim, other.scrim),
      overlayRemoved: mix(overlayRemoved, other.overlayRemoved),
      overlayKept: mix(overlayKept, other.overlayKept),
      photoChromeBg: mix(photoChromeBg, other.photoChromeBg),
      photoChromeFg: mix(photoChromeFg, other.photoChromeFg),
      mascotLid: mix(mascotLid, other.mascotLid),
      mascotPupil: mix(mascotPupil, other.mascotPupil),
      mascotPupilTeal: mix(mascotPupilTeal, other.mascotPupilTeal),
      mascotEyeWhite: mix(mascotEyeWhite, other.mascotEyeWhite),
      mascotRing: mix(mascotRing, other.mascotRing),
      mascotRingReady: mix(mascotRingReady, other.mascotRingReady),
    );
  }
}

typedef AppColors = AppPalette;
