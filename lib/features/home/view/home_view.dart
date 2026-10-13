import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../history/widgets/history_grid.dart';
import '../controller/home_controller.dart';
import '../widgets/interactive_demo_card.dart';
import '../widgets/saves_indicator.dart';

/// Home (S1) — Design Review 01 layout: the wordmark lives ONLY in the
/// app bar (left-aligned, Inter 800); the body is one top-anchored
/// column: saves indicator (line + thin bar), the one primary action,
/// then either the teaching line (no history yet) in flow, or the
/// History section. No spacers, no floating text, the app name appears
/// exactly once on this screen.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.sizes;
    return AppScaffold(
      titleKey: AppStrings.appName,
      titleStyle: context.textStyles.titleLg.copyWith(
        fontWeight: FontWeight.w800,
      ),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: AppStrings.settingsTitle.tr,
          onPressed: controller.openSettings,
        ),
      ],
      body: Obx(() {
        final error = controller.errorMessage.value;
        if (error != null) {
          return ErrorView(
            messageKey: error,
            onRetry: controller.onPickPhoto,
            actionLabelKey: AppStrings.errorPickAnother,
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(s.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PrimaryButton(
                labelKey: AppStrings.homePickPhoto,
                isLoading: controller.isPicking,
                onPressed: controller.onPickPhoto,
              ),
              SizedBox(height: s.sm),
              SavesIndicator(
                savesLeft: controller.savesLeft.value,
                of: HomeController.freeSavesPerMonth,
              ),
              if (!controller.hasHistory) ...<Widget>[
                SizedBox(height: s.xl),
                Text(
                  AppStrings.homeEmptyLine.tr,
                  style: context.textStyles.bodyLg,
                ),
                SizedBox(height: s.md),
                const InteractiveDemoCard(),
              ] else ...<Widget>[
                SizedBox(height: s.xxl),
                SectionHeader(
                  titleKey: AppStrings.homeHistory,
                  actionLabelKey: AppStrings.homeSeeAll,
                  onAction: controller.openHistory,
                ),
                SizedBox(height: s.md),
                // The same shared HistoryGrid as S9 — first row of 3,
                // never a Home-only 4-across variant (Review 02 F6).
                HistoryGrid(
                  entries: controller.history.take(3).toList(),
                  shrinkWrap: true,
                  onTap: (_) => controller.openHistory(),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}
