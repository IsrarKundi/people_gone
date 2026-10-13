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

  static const AppPalette light = AppPalette(
    primary: Color(0xFF3157D5),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE3E9FD),
    secondary: Color(0xFF0E7C86),
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEEF0F4),
    textPrimary: Color(0xFF16181D),
    textSecondary: Color(0xFF5A6068),
    textTertiary: Color(0xFF8A919C),
    border: Color(0xFFDFE3E9),
    success: Color(0xFF1E7D46),
    successBg: Color(0xFFE2F4E8),
    warning: Color(0xFF9A6A00),
    warningBg: Color(0xFFFBF0D3),
    error: Color(0xFFC0362C),
    errorBg: Color(0xFFFBE7E4),
    scrim: Color(0x8C0A0C10),
    overlayRemoved: Color(0x8CE5484D),
    overlayKept: Color(0x8C30A46C),
    photoChromeBg: Color(0x8C0A0C10),
    photoChromeFg: Color(0xFFFFFFFF),
  );

  static const AppPalette dark = AppPalette(
    primary: Color(0xFF8FA8FF),
    onPrimary: Color(0xFF0B1026),
    primaryContainer: Color(0xFF26335F),
    secondary: Color(0xFF45B8C4),
    background: Color(0xFF0E1013),
    surface: Color(0xFF17191E),
    surfaceVariant: Color(0xFF1F2229),
    textPrimary: Color(0xFFF2F3F5),
    textSecondary: Color(0xFFA7ADB8),
    textTertiary: Color(0xFF6E757F),
    border: Color(0xFF2A2E36),
    success: Color(0xFF4CC38A),
    successBg: Color(0xFF123527),
    warning: Color(0xFFF5C15C),
    warningBg: Color(0xFF3A2E10),
    error: Color(0xFFFF8A80),
    errorBg: Color(0xFF3A1D1A),
    scrim: Color(0x99000000),
    overlayRemoved: Color(0x8CFF6369),
    overlayKept: Color(0x8C3DD68C),
    photoChromeBg: Color(0x99000000),
    photoChromeFg: Color(0xFFFFFFFF),
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
    );
  }
}
