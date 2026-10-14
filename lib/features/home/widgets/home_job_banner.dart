import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../services/processing/job_tracker.dart';
import '../../processing/model/processing_args.dart';

/// Active Job Banner displayed at the top of Home when a clean is
/// running in the background, completed, or failed (Option 3 / backgrounding flow).
class HomeJobBanner extends StatelessWidget {
  const HomeJobBanner({super.key, required this.job});

  final ActiveJob job;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;

    Widget leadingIcon;
    String title;
    String subtitle;
    VoidCallback? onTap;

    switch (job.status) {
      case ActiveJobStatus.processing:
        leadingIcon = SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
        );
        title = AppStrings.homeJobBannerProcessing.tr;
        subtitle = AppStrings.homeJobBannerProcessingSub.tr;
        onTap = () {
          Get.toNamed<void>(
            Routes.processing,
            arguments: ProcessingArgs(
              photoPath: job.photoPath,
              keepIds: job.keepIds,
              removeItemIds: job.removeItemIds,
              detachedBelongingIds: job.detachedBelongingIds,
            ),
          );
        };
      case ActiveJobStatus.done:
        leadingIcon = Icon(
          Icons.check_circle_rounded,
          color: p.overlayKept,
          size: s.iconSm,
        );
        title = AppStrings.homeJobBannerDone.tr;
        subtitle = AppStrings.homeJobBannerDoneSub.tr;
        onTap = () {
          final outcome = job.outcome;
          if (outcome != null) {
            JobTracker.instance.clear();
            Get.toNamed<void>(Routes.result, arguments: outcome);
          }
        };
      case ActiveJobStatus.failed:
        leadingIcon = Icon(
          Icons.error_outline_rounded,
          color: p.overlayRemoved,
          size: s.iconSm,
        );
        title = AppStrings.homeJobBannerFailed.tr;
        subtitle = AppStrings.homeJobBannerFailedSub.tr;
        // Failed (Review 06 F2): the banner states the user's fact
        // ("No save was used") and tapping dismisses it — diagnostics
        // sharing lives on the error view and in Settings, not here.
        onTap = JobTracker.instance.clear;
    }

    // One card language (D12): neutral hairline border at the shared
    // card radius for every state — state colour lives in the icon,
    // never in the container outline (Review 05 W3).
    return Container(
      margin: EdgeInsets.only(bottom: s.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(s.radiusLg),
        border: Border.all(color: p.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(s.radiusLg),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm + 2),
            child: Row(
              children: <Widget>[
                leadingIcon,
                SizedBox(width: s.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: context.textStyles.labelLg.copyWith(
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: context.textStyles.caption.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (job.status != ActiveJobStatus.processing) ...<Widget>[
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: p.textTertiary),
                    onPressed: JobTracker.instance.clear,
                    tooltip: AppStrings.commonCancel.tr,
                  ),
                ] else ...<Widget>[
                  Icon(
                    Icons.chevron_right_rounded,
                    color: p.textTertiary,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
