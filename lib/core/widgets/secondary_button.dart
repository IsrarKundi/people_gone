import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/theme_ext.dart';

/// Secondary action button (Conventions §6.7): token height 48, outlined.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.labelKey,
    required this.onPressed,
  });

  final String labelKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return SizedBox(
      height: s.buttonSecondary,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(s.radiusMd),
          ),
          textStyle: context.textStyles.labelLg,
        ),
        child: Text(labelKey.tr),
      ),
    );
  }
}
