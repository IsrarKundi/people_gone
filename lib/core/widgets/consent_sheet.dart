import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../strings/app_strings.dart';
import '../theme/theme_ext.dart';
import 'primary_button.dart';

/// The two sanctioned ConsentSheet variants (Design Direction §4
/// S2/S10, Review 02 A4). *consent* asks the question — Continue /
/// Cancel, pre-upload only. *readOnly* only informs — a single Close;
/// two dismiss actions on one sheet is a reject.
enum ConsentSheetVariant { consent, readOnly }

/// Consent sheet SHELL only (Conventions §6.7). The wording comes from
/// strings/config and is versioned by `AppConfig.consentVersion`
/// (Requirements §11.2) — this widget owns layout, never copy.
class ConsentSheet extends StatelessWidget {
  const ConsentSheet({
    super.key,
    required this.titleKey,
    required this.bodyKey,
    required this.onContinue,
    this.onCancel,
    this.variant = ConsentSheetVariant.consent,
    this.bodyParams,
    this.continueLabelKey = AppStrings.commonContinue,
    this.footerKey,
    this.onFooterTap,
  });

  final String titleKey;
  final String bodyKey;

  /// Interpolation params for the body (e.g. the provider display name
  /// from AppConfig — §11.2A wording is config-driven, never hard-coded).
  final Map<String, String>? bodyParams;
  final VoidCallback onContinue;

  /// Consent variant only — the read-only variant has no Cancel
  /// (Review 02 F5).
  final VoidCallback? onCancel;
  final ConsentSheetVariant variant;
  final String continueLabelKey;

  /// Optional link row under the body (e.g. "Full details: Privacy
  /// Policy", §11.2A).
  final String? footerKey;
  final VoidCallback? onFooterTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(s.radiusSheet),
        ),
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
          Text(
            bodyParams == null ? bodyKey.tr : bodyKey.trParams(bodyParams!),
            style: context.textStyles.bodyMd,
          ),
          if (footerKey != null && onFooterTap != null) ...<Widget>[
            SizedBox(height: s.md),
            GestureDetector(
              onTap: onFooterTap,
              child: Text(
                footerKey!.tr,
                style: context.textStyles.bodyMd.copyWith(
                  color: p.secondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
          SizedBox(height: s.xxl),
          PrimaryButton(labelKey: continueLabelKey, onPressed: onContinue),
          if (variant == ConsentSheetVariant.consent &&
              onCancel != null) ...<Widget>[
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
        ],
      ),
    );
  }
}
