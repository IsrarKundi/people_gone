import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../controller/settings_controller.dart';

/// Settings — flat rows, values from state/config only.
class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.sizes;
    return AppScaffold(
      titleKey: AppStrings.settingsTitle,
      body: ListView(
        padding: EdgeInsets.all(s.screenPadding),
        children: <Widget>[
          const SectionHeader(titleKey: AppStrings.settingsYourPlan),
          Obx(
            () => _row(
              context,
              label: AppStrings.homeSavesLeft.trParams(<String, String>{
                'count': '${controller.savesLeft.value}',
              }),
            ),
          ),
          SizedBox(height: s.xxl),
          _row(
            context,
            label: AppStrings.settingsProcessingProvider.tr,
            value: controller.providerName,
          ),
          _actionRow(
            context,
            label: AppStrings.settingsHowHandled.tr,
            onTap: controller.showPhotoHandling,
          ),
          _actionRow(
            context,
            label: AppStrings.settingsPrivacyPolicy.tr,
            onTap: controller.openPrivacyPolicy,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, {required String label, String? value}) {
    final p = context.palette;
    final s = context.sizes;
    return SizedBox(
      height: s.listRowMin,
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: context.textStyles.bodyMd)),
          if (value != null)
            Text(
              value,
              style: context.textStyles.bodyMd.copyWith(color: p.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _actionRow(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    final p = context.palette;
    final s = context.sizes;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: s.listRowMin,
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: context.textStyles.bodyMd)),
            Icon(Icons.chevron_right, color: p.textSecondary),
          ],
        ),
      ),
    );
  }
}
