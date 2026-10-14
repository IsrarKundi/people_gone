import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../services/processing/job_tracker.dart';
import '../controller/home_controller.dart';
import '../widgets/earlier_cleans_tray.dart';
import '../widgets/featured_clean_card.dart';
import '../widgets/home_job_banner.dart';
import '../widgets/interactive_demo_card.dart';
import '../widgets/saves_indicator.dart';

/// Home (S1) — Option A: "The Photographic Drop-Zone Studio"
/// Leads with the primary 56dp action pill and quiet quota pill, followed
/// immediately by visual proof (interactive café before/after card on first run,
/// natural-aspect latest clean card + earlier cleans tray on return).
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

        final activeJob = JobTracker.instance.activeJob.value;

        return SingleChildScrollView(
          padding: EdgeInsets.all(s.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // In-flight or completed background job banner
              if (activeJob != null) HomeJobBanner(job: activeJob),

              // Floating 56dp Pill Primary Button
              PrimaryButton(
                labelKey: AppStrings.homePickPhoto,
                icon: Icons.add_photo_alternate_rounded,
                height: 56,
                borderRadius: 28,
                isLoading: controller.isPicking,
                onPressed: controller.onPickPhoto,
              ),

              SizedBox(height: s.sm),

              // Quiet Quota Pill
              SavesIndicator(
                savesLeft: controller.savesLeft.value,
                of: HomeController.freeSavesPerMonth,
                resetDate: controller.resetDate.value,
              ),

              SizedBox(height: s.lg),

              // Hero section:
              if (!controller.hasHistory) ...<Widget>[
                Text(
                  AppStrings.homeEmptyLine.tr,
                  style: context.textStyles.bodyLg,
                ),
                SizedBox(height: s.md),
                const InteractiveDemoCard(),
              ] else ...<Widget>[
                SectionHeader(
                  titleKey: AppStrings.homeHistory,
                  actionLabelKey: AppStrings.homeSeeAll,
                  onAction: controller.openHistory,
                ),
                SizedBox(height: s.sm),
                // Latest Cleaned Photo in its natural aspect ratio
                FeaturedCleanCard(
                  entry: controller.history.first,
                  onTap: () => controller.openHistoryDetail(controller.history.first),
                ),
                if (controller.history.length > 1) ...<Widget>[
                  SizedBox(height: s.lg),
                  EarlierCleansTray(
                    entries: controller.history.skip(1).take(10).toList(),
                    onTap: controller.openHistoryDetail,
                  ),
                ],
              ],

              SizedBox(height: s.lg),
            ],
          ),
        );
      }),
    );
  }
}
