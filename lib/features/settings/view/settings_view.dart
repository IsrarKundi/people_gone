import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../controller/settings_controller.dart';

/// Settings — flat rows, values from state/config only.
class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return AppScaffold(
      titleKey: AppStrings.settingsTitle,
      body: ListView(
        padding: EdgeInsets.all(s.screenPadding),
        children: <Widget>[
          const SectionHeader(titleKey: AppStrings.settingsYourPlan),
          SizedBox(height: s.sm),
          _cardContainer(
            context,
            child: Obx(() {
              final reset = controller.resetDate.value;
              return _row(
                context,
                icon: Icons.savings_outlined,
                label: reset == null
                    ? AppStrings.homeSavesLeft.trParams(<String, String>{
                        'count': '${controller.savesLeft.value}',
                      })
                    : AppStrings.settingsSavesLeft.trParams(<String, String>{
                        'count': '${controller.savesLeft.value}',
                        'date': Formatters.dayMonth(reset),
                      }),
              );
            }),
          ),
          SizedBox(height: s.xl),
          const SectionHeader(titleKey: AppStrings.settingsProcessingPrivacy),
          SizedBox(height: s.sm),
          _cardContainer(
            context,
            child: Column(
              children: <Widget>[
                _providerRow(
                  context,
                  icon: Icons.dns_outlined,
                  label: AppStrings.settingsProcessingProvider.tr,
                  value: controller.providerName,
                ),
                Divider(height: 1, color: p.border),
                _actionRow(
                  context,
                  icon: Icons.shield_outlined,
                  label: AppStrings.settingsHowHandled.tr,
                  onTap: controller.showPhotoHandling,
                ),
                Divider(height: 1, color: p.border),
                _actionRow(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  label: AppStrings.settingsPrivacyPolicy.tr,
                  onTap: controller.openPrivacyPolicy,
                ),
                Divider(height: 1, color: p.border),
                _actionRow(
                  context,
                  icon: Icons.bug_report_outlined,
                  label: AppStrings.diagnosticsTitle.tr,
                  onTap: controller.openDiagnostics,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardContainer(BuildContext context, {required Widget child}) {
    final p = context.palette;
    final s = context.sizes;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(s.radiusMd),
        border: Border.all(color: p.border),
      ),
      padding: EdgeInsets.symmetric(horizontal: s.md),
      child: child,
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    IconData? icon,
    String? value,
  }) {
    final p = context.palette;
    final s = context.sizes;
    return SizedBox(
      height: s.listRowMin,
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: s.iconSm, color: p.primary),
            SizedBox(width: s.sm),
          ],
          Expanded(child: Text(label, style: context.textStyles.bodyMd)),
          if (value != null) ...<Widget>[
            SizedBox(width: s.sm),
            Text(
              value,
              style: context.textStyles.bodyMd.copyWith(color: p.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  /// Provider row (Review 04 F8): the LABEL takes layout priority and
  /// the value wraps BENEATH it, so the label can never be squeezed
  /// into a letter column by a long single-line value — at 1.30 text
  /// scale or any other.
  Widget _providerRow(
    BuildContext context, {
    required String label,
    required String value,
    IconData? icon,
  }) {
    final p = context.palette;
    final s = context.sizes;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: s.iconSm, color: p.primary),
                SizedBox(width: s.sm),
              ],
              Expanded(child: Text(label, style: context.textStyles.bodyMd)),
            ],
          ),
          SizedBox(height: s.xs),
          Padding(
            padding: EdgeInsets.only(left: icon != null ? s.iconSm + s.sm : 0),
            child: Text(
              value,
              style: context.textStyles.bodyMd.copyWith(color: p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final p = context.palette;
    final s = context.sizes;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: s.listRowMin,
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: s.iconSm, color: p.primary),
              SizedBox(width: s.sm),
            ],
            Expanded(child: Text(label, style: context.textStyles.bodyMd)),
            Icon(Icons.chevron_right, color: p.textSecondary),
          ],
        ),
      ),
    );
  }
}
