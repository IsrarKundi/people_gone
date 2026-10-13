import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../strings/app_strings.dart';
import '../theme/theme_ext.dart';
import 'primary_button.dart';

/// Consent sheet SHELL only (Conventions §6.7). The wording comes from
/// strings/config and is versioned by `AppConfig.consentVersion`
/// (Requirements §11.2) — this widget owns layout, never copy.
class ConsentSheet extends StatelessWidget {
  const ConsentSheet({
    super.key,
    required this.titleKey,
    required this.bodyKey,
    required this.onContinue,
    required this.onCancel,
  });

  final String titleKey;
  final String bodyKey;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(s.radiusSheet)),
      ),
      padding: EdgeInsets.fromLTRB(
        s.screenPadding,
        s.xxl,
        s.screenPadding,
        s.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(titleKey.tr, style: context.textStyles.titleLg),
          SizedBox(height: s.md),
          Text(bodyKey.tr, style: context.textStyles.bodyMd),
          SizedBox(height: s.xxl),
          PrimaryButton(
            labelKey: AppStrings.commonContinue,
            onPressed: onContinue,
          ),
          SizedBox(height: s.sm),
          Center(
            child: TextButton(
              onPressed: onCancel,
              child: Text(
                AppStrings.commonCancel.tr,
                style: context.textStyles.labelLg.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
