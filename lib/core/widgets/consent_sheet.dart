import 'package:flutter/material.dart';
import '../constants/app_icons.dart';
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
    final isConsentBody = bodyKey == AppStrings.consentBody;
    final provider =
        bodyParams?['provider'] ?? "Framora's processing servers";

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(s.radiusSheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        s.screenPadding,
        s.xl,
        s.screenPadding,
        s.xl,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(titleKey.tr, style: context.textStyles.titleLg),
              SizedBox(height: s.md),
              if (isConsentBody)
                _structuredBody(context, provider)
              else
                Text(
                  bodyParams == null ? bodyKey.tr : bodyKey.trParams(bodyParams!),
                  style: context.textStyles.bodyMd,
                ),
              if (footerKey != null && onFooterTap != null) ...<Widget>[
                SizedBox(height: s.md),
                GestureDetector(
                  onTap: onFooterTap,
                  child: Row(
                    children: <Widget>[
                      Icon(AppIcons.privacy, size: s.iconSm, color: p.primary),
                      SizedBox(width: s.xs),
                      Text(
                        footerKey!.tr,
                        style: context.textStyles.bodySm.copyWith(
                          color: p.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: s.xl),
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
        ),
      ),
    );
  }

  Widget _structuredBody(BuildContext context, String provider) {
    final p = context.palette;
    final s = context.sizes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _trustItem(
          context,
          icon: AppIcons.lock,
          iconColor: p.primary,
          title: 'Encrypted single-photo transfer',
          desc:
              'Sent to $provider over an encrypted connection. '
              'Only this photo is sent — Framora never accesses the rest of your photo library.',
        ),
        SizedBox(height: s.sm),
        _trustItem(
          context,
          icon: AppIcons.shield,
          iconColor: p.success,
          title: 'Never used to train AI',
          desc:
              'Your photo is used solely to remove background people. '
              'It is never used to train AI models.',
        ),
        SizedBox(height: s.sm),
        _trustItem(
          context,
          icon: AppIcons.autoDelete,
          iconColor: p.secondary,
          title: 'Deleted within 24 hours',
          desc:
              'Permanently deleted from our servers when processing finishes, '
              'and in all cases within 24 hours.',
        ),
      ],
    );
  }

  Widget _trustItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    final p = context.palette;
    final s = context.sizes;
    return Container(
      padding: EdgeInsets.all(s.md),
      decoration: BoxDecoration(
        color: p.surfaceVariant,
        borderRadius: BorderRadius.circular(s.radiusMd),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: s.xxs),
            child: Icon(icon, color: iconColor, size: s.iconMd),
          ),
          SizedBox(width: s.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: context.textStyles.labelLg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: s.xxs),
                Text(
                  desc,
                  style: context.textStyles.bodySm.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
