import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/cam_frame.dart';
import '../../../core/widgets/cam_mascot.dart';
import '../../../core/widgets/primary_button.dart';
import '../controller/paywall_controller.dart';
import '../widgets/plan_tile.dart';

/// S8 Paywall — Option A, photo-first design (Audit 2026-10-19, Task 2).
///
/// Converts a user holding a finished result (or at 0 saves).
/// The hero is the user's OWN photo (unblurred, unwatermarked).
/// Annual is the visual anchor; Lifetime and Monthly are quiet secondary options.
/// Calm factual voice: no countdowns, no fake discounts, no confetti.
class PaywallView extends GetView<PaywallController> {
  const PaywallView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Top chrome bar with close button
            _buildTopBar(context),

            // Scrollable paywall content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: s.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Hero photo (when available)
                    if (controller.hasPhoto) ...<Widget>[
                      _buildHeroPhoto(context),
                      SizedBox(height: s.md),
                    ],

                    // Arrival context note if blocked at save
                    if (controller.arrivalReason != null) ...<Widget>[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: s.md,
                          vertical: s.sm,
                        ),
                        decoration: BoxDecoration(
                          color: p.surfaceVariant,
                          borderRadius: BorderRadius.circular(s.radiusMd),
                          border: Border.all(color: p.border),
                        ),
                        child: Text(
                          controller.arrivalReason!,
                          style: context.textStyles.bodySm.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                      SizedBox(height: s.md),
                    ],

                    // Headline in Poppins displayBrand
                    Text(
                      AppStrings.paywallHeadline.tr,
                      style: context.textStyles.displayBrand.copyWith(
                        color: p.textPrimary,
                        fontSize: 24,
                      ),
                    ),
                    SizedBox(height: s.xs),

                    // Subhead
                    Text(
                      AppStrings.paywallSubhead.tr,
                      style: context.textStyles.bodyMd.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                    SizedBox(height: s.lg),

                    // Plan selection tiles
                    Obx(() => _buildPlanTiles(context)),
                    SizedBox(height: s.lg),

                    // Focal CTA
                    Obx(() {
                      final plan = controller.selectedPlan.value;
                      final String ctaKey;
                      switch (plan) {
                        case 'yearly':
                          ctaKey = AppStrings.paywallContinueYearly;
                        case 'lifetime':
                          ctaKey = AppStrings.paywallContinueLifetime;
                        case 'monthly':
                          ctaKey = AppStrings.paywallContinueMonthly;
                        default:
                          ctaKey = AppStrings.paywallContinue;
                      }
                      return PrimaryButton(
                        labelKey: ctaKey,
                        onPressed: controller.onContinue,
                      );
                    }),
                    SizedBox(height: s.sm),

                    // Terms block (plain sentences, bodySm/caption)
                    Obx(() {
                      final plan = controller.selectedPlan.value;
                      final String termsKey;
                      switch (plan) {
                        case 'lifetime':
                          termsKey = AppStrings.paywallTermsLifetime;
                        case 'monthly':
                          termsKey = AppStrings.paywallTermsMonthly;
                        default:
                          termsKey = AppStrings.paywallTermsYearly;
                      }
                      return Text(
                        termsKey.tr,
                        textAlign: TextAlign.center,
                        style: context.textStyles.caption.copyWith(
                          color: p.textTertiary,
                        ),
                      );
                    }),
                    SizedBox(height: s.md),

                    // Restore Purchases & Not now
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        TextButton(
                          onPressed: controller.restore,
                          child: Text(
                            AppStrings.paywallRestore.tr,
                            style: context.textStyles.labelMd.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          '·',
                          style: context.textStyles.labelMd.copyWith(
                            color: p.textTertiary,
                          ),
                        ),
                        TextButton(
                          onPressed: controller.close,
                          child: Text(
                            AppStrings.paywallNotNow.tr,
                            style: context.textStyles.labelMd.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (controller.hasPhoto) ...<Widget>[
                      Text(
                        AppStrings.paywallNotNowNote.tr,
                        textAlign: TextAlign.center,
                        style: context.textStyles.caption.copyWith(
                          color: p.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],

                    // Cam presenter (ADR docs/architecture/cam-mascot.md):
                    // centred in the space below the Restore · Not now
                    // row, xxxl (32) below it — beyond the plan's ≥24dp
                    // minimum — and clear of every control. Display only.
                    SizedBox(height: s.xxxl),
                    const Center(child: CamMascot(mode: CamMode.presenter)),

                    SizedBox(height: s.md),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: s.screenPadding,
        vertical: s.xs,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: AppStrings.commonClose.tr,
            icon: Icon(AppIcons.close, color: p.textPrimary),
            onPressed: controller.close,
          ),
          SizedBox(width: s.xs),
          Expanded(
            child: Text(
              AppStrings.paywallTitle.tr,
              style: context.textStyles.titleMd.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPhoto(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final file = File(controller.photoPath!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(s.photoRadius),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: p.surfaceVariant,
          border: Border.all(color: p.border),
          borderRadius: BorderRadius.circular(s.photoRadius),
        ),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Center(
            child: Icon(AppIcons.photoLibrary, size: 48, color: p.textTertiary),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanTiles(BuildContext context) {
    final s = context.sizes;
    final selected = controller.selectedPlan.value;

    return Column(
      children: <Widget>[
        // 1. Annual (pre-selected visual anchor)
        PlanTile(
          title: AppStrings.paywallPlanYearlyTitle.tr,
          subtitle: AppStrings.paywallPlanYearlySubtitle.tr,
          price: controller.priceFor('yearly'),
          isSelected: selected == 'yearly',
          onTap: () => controller.selectPlan('yearly'),
        ),
        SizedBox(height: s.sm),

        // 2. Lifetime (equally visible secondary)
        PlanTile(
          title: AppStrings.paywallPlanLifetimeTitle.tr,
          subtitle: AppStrings.paywallPlanLifetimeSubtitle.tr,
          price: controller.priceFor('lifetime'),
          isSelected: selected == 'lifetime',
          onTap: () => controller.selectPlan('lifetime'),
        ),
        SizedBox(height: s.sm),

        // 3. Monthly (quiet secondary)
        PlanTile(
          title: AppStrings.paywallPlanMonthlyTitle.tr,
          subtitle: AppStrings.paywallPlanMonthlySubtitle.tr,
          price: controller.priceFor('monthly'),
          isSelected: selected == 'monthly',
          onTap: () => controller.selectPlan('monthly'),
        ),
      ],
    );
  }
}
