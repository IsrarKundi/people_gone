import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/theme_ext.dart';
import 'pressable_scale.dart';


/// Primary action button (Conventions §6.7): token height 52, built-in
/// loading state (spinner replaces the label, button disabled).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.labelKey,
    required this.onPressed,
    this.isLoading = false,
    this.labelParams,
    this.icon,
    this.height,
    this.borderRadius,
    this.loadingLabelKey,
  });

  /// String key; buttons are named by their outcome (Design Direction §1).
  final String labelKey;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Map<String, String>? labelParams;
  final IconData? icon;
  final double? height;
  final double? borderRadius;

  /// When set, the loading state keeps a label beside the spinner
  /// (Review 07 B4: a loading button keeps its label — it never
  /// collapses into a blank slab). When null, loading shows the
  /// spinner alone, as before.
  final String? loadingLabelKey;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    // A labelled loading state keeps the button's identity (Review 07
    // B4): it renders as the filled primary with an inert tap, never
    // as the pale disabled slab. Unlabelled loading disables as before.
    final busyWithLabel = isLoading && loadingLabelKey != null;
    final disabled = !busyWithLabel && (isLoading || onPressed == null);
    final h = height ?? s.buttonPrimary;
    final r = borderRadius ?? s.radiusLg;
    return PressableScale(
      enabled: !disabled,
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: ElevatedButton(

        onPressed: disabled
            ? null
            : busyWithLabel
            ? () {}
            : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.surfaceVariant,
          disabledForegroundColor: p.textTertiary,
          elevation: disabled ? 0 : 2,
          shadowColor: p.primary.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r)),
          textStyle: context.textStyles.labelLg.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),

        child: isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: s.iconSm,
                    height: s.iconSm,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.onPrimary,
                    ),
                  ),
                  if (loadingLabelKey != null) ...<Widget>[
                    SizedBox(width: s.sm),
                    Text(loadingLabelKey!.tr),
                  ],
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: s.iconSm, color: p.onPrimary),
                    SizedBox(width: s.sm),
                  ],
                  Text(
                    labelParams != null
                        ? labelKey.trParams(labelParams!)
                        : labelKey.tr,
                  ),
                ],
              ),
      ),
    ),
    );
  }
}

