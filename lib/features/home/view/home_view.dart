import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_motion.dart';
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

/// Home (S1) — Option A composition, finished per Review 05 Supplement
/// (R2–R4, D10): the screen is a finished arrangement anchored top AND
/// bottom. The hero slot is sized from the actual viewport height
/// (body height minus a budgeted allowance for the fixed cluster above
/// and below it), so the hero takes its adopted scale and the screen
/// ends at the tray — never a terminal void. If the budget is off
/// (very large text, very small phone) the page simply scrolls, which
/// is the sanctioned degradation. No intrinsic-sizing widgets are
/// used, so the hero cards may size themselves with LayoutBuilder.
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
        final hasHistory = controller.hasHistory;
        final hasTray = hasHistory && controller.history.length > 1;

        return LayoutBuilder(
          builder: (context, constraints) {
            // Budgeted hero height: everything that is not the hero.
            var reserved =
                s.screenPadding *
                    2 // page padding
                    +
                56 // pick pill
                +
                s
                    .sm // gap
                    +
                20 // saves line
                +
                s.lg; // gap above the hero zone
            if (activeJob != null) reserved += 92; // banner + its margin
            if (!hasHistory) {
              reserved += 24 + s.md; // teaching line + gap
            } else {
              reserved += 36 + s.sm; // section header + gap
              if (hasTray) reserved += s.lg + 168; // gap + tray row
            }
            final heroHeight = (constraints.maxHeight - reserved)
                .clamp(240.0, constraints.maxHeight)
                .toDouble();

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

                  // The saves fact as a plain line in the column
                  SavesIndicator(
                    savesLeft: controller.savesLeft.value,
                    of: HomeController.freeSavesPerMonth,
                    resetDate: controller.resetDate.value,
                  ),

                  SizedBox(height: s.lg),

                  // Hero zone — sized to finish the screen.
                  if (!hasHistory) ...<Widget>[
                    Text(
                      AppStrings.homeEmptyLine.tr,
                      style: context.textStyles.bodyMd,
                    ),
                    SizedBox(height: s.md),
                    SizedBox(
                      height: heroHeight,
                      child: const InteractiveDemoCard(),
                    ),
                  ] else ...<Widget>[
                    _HomeHistoryBlockFade(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SectionHeader(
                            titleKey: AppStrings.homeHistory,
                            actionLabelKey: AppStrings.homeSeeAll,
                            onAction: controller.openHistory,
                          ),
                          SizedBox(height: s.sm),
                          SizedBox(
                            height: heroHeight,
                            child: FeaturedCleanCard(
                              entry: controller.history.first,
                              onTap: () => controller.openHistoryDetail(
                                controller.history.first,
                              ),
                            ),
                          ),
                          if (hasTray) ...<Widget>[
                            SizedBox(height: s.lg),
                            EarlierCleansTray(
                              entries: controller.history.skip(1).take(10).toList(),
                              onTap: controller.openHistoryDetail,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

/// Single block fade-in for the Home history section when it first loads
/// with data (ANIMATION_RESEARCH_2026.md §3, #6). NO per-item stagger.
class _HomeHistoryBlockFade extends StatefulWidget {
  const _HomeHistoryBlockFade({required this.child});

  final Widget child;

  @override
  State<_HomeHistoryBlockFade> createState() => _HomeHistoryBlockFadeState();
}

class _HomeHistoryBlockFadeState extends State<_HomeHistoryBlockFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _controller,
        curve: AppMotion.enterCurve,
      ),
      child: widget.child,
    );
  }
}

