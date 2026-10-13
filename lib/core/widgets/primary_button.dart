import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/theme_ext.dart';

/// Primary action button (Conventions §6.7): token height 52, built-in
/// loading state (spinner replaces the label, button disabled).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.labelKey,
    required this.onPressed,
    this.isLoading = false,
    this.labelParams,
  });

  /// String key; buttons are named by their outcome (Design Direction §1).
  final String labelKey;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Map<String, String>? labelParams;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final disabled = isLoading || onPressed == null;
    return SizedBox(
      height: s.buttonPrimary,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.surfaceVariant,
          disabledForegroundColor: p.textTertiary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(s.radiusMd),
          ),
          textStyle: context.textStyles.labelLg,
        ),
        child: isLoading
            ? SizedBox(
                width: s.iconSm,
                height: s.iconSm,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: p.onPrimary,
                ),
              )
            : Text(labelParams != null ? labelKey.trParams(labelParams!) : labelKey.tr),
      ),
    );
  }
}
