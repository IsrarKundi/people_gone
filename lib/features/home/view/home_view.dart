import 'package:flutter/material.dart';
import '../../../core/constants/app_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_motion.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/cam_frame.dart';
import '../../../core/widgets/cam_mascot.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/primary_button.dart';
// import '../../../core/widgets/section_header.dart';
import '../../../services/processing/job_tracker.dart';
import '../controller/home_controller.dart';
import '../widgets/earlier_cleans_tray.dart';
// import '../widgets/featured_clean_card.dart';
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
    final p = context.palette;
    final s = context.sizes;
    return AppScaffold(
      titleWidget: SvgPicture.asset(
        'assets/icons/framora_logo.svg',
        height: 24,
        theme: SvgTheme(currentColor: p.textPrimary),
      ),
      actions: <Widget>[
        // Cam avatar (ADR docs/architecture/cam-mascot.md): face only,
        // centred on the wordmark row by the AppBar; display only in
        // v1 — no tap action. Header end-padding from the screen edge.
        Padding(
          padding: EdgeInsets.only(right: s.screenPadding),
          child: const CamMascot(mode: CamMode.avatar),
        ),
        // IconButton(
        //   icon: const Icon(AppIcons.gear),
        //   tooltip: AppStrings.settingsTitle.tr,
        //   onPressed: controller.openSettings,
        // ),
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

        return Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(s.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 1. The demo as a HORIZONTAL card — wide and short band across screen
                    const SizedBox(height: 250, child: InteractiveDemoCard()),

                    if (activeJob != null) ...<Widget>[
                      SizedBox(height: s.md),
                      HomeJobBanner(job: activeJob),
                    ],

                    if (hasHistory) ...<Widget>[
                      SizedBox(height: s.sm),
                      _HomeHistoryBlockFade(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: [
                                Text(
                                  AppStrings.homeHistory.tr,
                                  style: context.textStyles.titleMd,
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: controller.openHistory,
                                  child: Text(
                                    AppStrings.homeSeeAll.tr,
                                    style: context.textStyles.labelMd.copyWith(
                                      color: p.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // SizedBox(height: s.sm),
                            // SizedBox(
                            //   height: 240,
                            //   child: FeaturedCleanCard(
                            //     entry: controller.history.first,
                            //     onTap: () => controller.openHistoryDetail(
                            //       controller.history.first,
                            //     ),
                            //   ),
                            // ),
                            if (hasTray) ...<Widget>[
                              EarlierCleansTray(
                                entries: controller.history.take(10).toList(),
                                onTap: controller.openHistoryDetail,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Bottom thumb-zone dock for Pick + saves line (G3.1)
            Container(
              padding: EdgeInsets.fromLTRB(
                s.screenPadding,
                s.xs,
                s.screenPadding,
                s.screenPadding,
              ),
              decoration: BoxDecoration(
                color: p.background,
                border: Border(
                  top: BorderSide(color: p.border.withValues(alpha: 0.5)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PrimaryButton(
                    labelKey: AppStrings.homePickPhoto,
                    icon: AppIcons.camera,
                    height: 48,
                    borderRadius: 28,
                    isLoading: controller.isPicking,
                    onPressed: controller.onPickPhoto,
                  ),
                  SizedBox(height: s.xs),
                  SavesIndicator(
                    savesLeft: controller.savesLeft.value,
                    of: HomeController.freeSavesPerMonth,
                    resetDate: controller.resetDate.value,
                    onTap: controller.openPaywall,
                  ),
                ],
              ),
            ),
          ],
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
