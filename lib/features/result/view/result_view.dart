import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/photo_surface.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../controller/result_controller.dart';
import '../widgets/compare_slider.dart';
import '../widgets/disclosure_line.dart';

/// Result (S7) — the cleaned photo full-bleed; judge it (hold-to-compare
/// + slider compare, FR-13), then Save / Share / fix. The saves meter
/// is stated before the Save tap (FR-25); the disclosure line is
/// verbatim §11.2B.
class ResultView extends GetView<ResultController> {
  const ResultView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return AppScaffold(
      body: Column(
        children: <Widget>[
          Expanded(child: _photoArea(context)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(s.screenPadding),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.border)),
            ),
            // nobodyRemoved never changes during this screen's life, so
            // its static zone stays outside the Obx (which must read at
            // least one observable).
            child: controller.nobodyRemoved
                ? _nobodyZone(context)
                : Obx(() => _actionZone(context)),
          ),
        ],
      ),
    );
  }

  Widget _nobodyZone(BuildContext context) {
    final s = context.sizes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(AppStrings.errorNoPeople.tr, style: context.textStyles.bodyMd),
        SizedBox(height: s.lg),
        PrimaryButton(
          labelKey: AppStrings.resultPickAnother,
          onPressed: controller.pickAnother,
        ),
        SizedBox(height: s.sm),
        SecondaryButton(
          labelKey: AppStrings.resultBrushFix,
          onPressed: controller.openTouchUp,
        ),
      ],
    );
  }

  Widget _photoArea(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final outcome = controller.outcome;
    if (controller.nobodyRemoved) {
      return Image.file(
        File(outcome.originalPath),
        fit: BoxFit.contain,
        cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return Obx(() {
      final comparing = controller.compareMode.value;
      final holding = controller.showOriginal.value;
      final shownPath = holding && !comparing
          ? outcome.originalPath
          : controller.resultPath.value;
      return PhotoSurface(
        imageProvider: ResizeImage(
          FileImage(File(shownPath)),
          width: MediaQuery.sizeOf(context).width.toInt(),
        ),
        builder: (context, band) => Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (comparing)
              CompareSlider(
                originalPath: outcome.originalPath,
                resultPath: controller.resultPath.value,
              )
            else
              GestureDetector(
                onLongPressStart: (_) => controller.showOriginal.value = true,
                onLongPressEnd: (_) => controller.showOriginal.value = false,
                onLongPressCancel: () => controller.showOriginal.value = false,
                child: Image.file(
                  File(shownPath),
                  fit: BoxFit.contain,
                  cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            // Chrome pins to the PHOTO band's top corners, on the
            // Polished studio chrome anchored gracefully at the top of the photo band
            Positioned(
              left: band.left + s.sm,
              top: band.top + s.sm,
              width: (band.width - s.sm * 2).clamp(0.0, double.infinity),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _chromeButton(
                    context,
                    icon: Icons.close,
                    onPressed: controller.goHome,
                  ),
                  if (holding && !comparing)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: s.md,
                        vertical: s.xs,
                      ),
                      decoration: BoxDecoration(
                        color: p.photoChromeBg,
                        borderRadius: BorderRadius.circular(s.radiusPill),
                      ),
                      child: Text(
                        AppStrings.resultOriginal.tr,
                        style: context.textStyles.labelMd.copyWith(
                          color: p.photoChromeFg,
                        ),
                      ),
                    )
                  else
                    _chromeButton(
                      context,
                      icon: Icons.compare,
                      onPressed: controller.toggleCompare,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _chromeButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final p = context.palette;
    final s = context.sizes;
    return Container(
      width: s.giant,
      height: s.giant,
      decoration: BoxDecoration(color: p.photoChromeBg, shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, color: p.photoChromeFg, size: s.iconMd),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: s.giant, height: s.giant),
        onPressed: onPressed,
      ),
    );
  }

  Widget _actionZone(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final savedNow = controller.saved.value;
    final left = controller.savesLeft.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Fact 1: People removed count with clean subject indicator
        Row(
          children: <Widget>[
            Icon(Icons.check_circle_outline, size: 18, color: p.overlayKept),
            SizedBox(width: s.xs),
            Expanded(
              child: Text(
                AppStrings.resultSummary.trParams(<String, String>{
                  'removed': '${controller.removedCount}',
                  'total': '${controller.totalCount}',
                }),
                style: context.textStyles.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: s.xs),
        // Fact 2: Save quota cost & remaining
        if (!savedNow) ...<Widget>[
          Text(
            left > 0
                ? AppStrings.resultSaveUses.trParams(<String, String>{
                    'count': '${left - 1}',
                  })
                : AppStrings.resultNoSaves.tr,
            style: context.textStyles.bodySm.copyWith(color: p.textSecondary),
          ),
          SizedBox(height: 2),
          // Fact 3: Location data removal
          Text(
            AppStrings.resultLocationNote.tr,
            style: context.textStyles.caption.copyWith(color: p.textTertiary),
          ),
        ],
        SizedBox(height: s.md),
        // Dominant action row with 75% primary save
        Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: PrimaryButton(
                labelKey: savedNow
                    ? AppStrings.resultSaved
                    : AppStrings.resultSave,
                isLoading: controller.isSaving.value,
                onPressed: savedNow ? null : controller.save,
              ),
            ),
            SizedBox(width: s.sm),
            Expanded(
              flex: 1,
              child: SecondaryButton(
                labelKey: AppStrings.resultShare,
                onPressed: controller.share,
              ),
            ),
          ],
        ),
        SizedBox(height: s.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: SecondaryButton(
                labelKey: AppStrings.resultBrushFix,
                onPressed: controller.openTouchUp,
              ),
            ),
          ],
        ),
        if (controller.canCorrectKeeper) ...<Widget>[
          SizedBox(height: s.xs),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: controller.openKeeperSheet,
              icon: Icon(Icons.swap_horiz, size: 18, color: p.primary),
              label: Text(
                AppStrings.resultWrongKeeper.tr,
                style: context.textStyles.labelMd.copyWith(color: p.primary),
              ),
            ),
          ),
        ],
        SizedBox(height: s.xs),
        // Fact 4 & 5: Verbatim §11.2B deletion & report disclosure
        DisclosureLine(onReport: controller.report),
      ],
    );
  }
}
