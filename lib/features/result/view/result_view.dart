import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
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
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (comparing)
            CompareSlider(
              originalPath: outcome.originalPath,
              resultPath: outcome.resultPath,
            )
          else
            GestureDetector(
              onLongPressStart: (_) => controller.showOriginal.value = true,
              onLongPressEnd: (_) => controller.showOriginal.value = false,
              onLongPressCancel: () => controller.showOriginal.value = false,
              child: Image.file(
                File(holding ? outcome.originalPath : outcome.resultPath),
                fit: BoxFit.contain,
                cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Positioned(
            left: s.screenPadding,
            right: s.screenPadding,
            top: s.screenPadding,
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
      );
    });
  }

  Widget _chromeButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(color: p.photoChromeBg, shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, color: p.photoChromeFg),
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
        Text(
          AppStrings.resultSummary.trParams(<String, String>{
            'removed': '${controller.removedCount}',
            'total': '${controller.totalCount}',
          }),
          style: context.textStyles.bodyMd,
        ),
        SizedBox(height: s.sm),
        if (!savedNow)
          Text(
            left > 0
                ? AppStrings.resultSaveUses.trParams(<String, String>{
                    'count': '${left - 1}',
                  })
                : AppStrings.resultNoSaves.tr,
            style: context.textStyles.bodyMd,
          ),
        if (!savedNow) ...<Widget>[
          SizedBox(height: s.xs),
          Text(
            AppStrings.resultLocationNote.tr,
            style: context.textStyles.bodySm.copyWith(color: p.textSecondary),
          ),
        ],
        SizedBox(height: s.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: PrimaryButton(
                labelKey: savedNow
                    ? AppStrings.resultSaved
                    : AppStrings.resultSave,
                isLoading: controller.isSaving.value,
                onPressed: savedNow ? null : controller.save,
              ),
            ),
            SizedBox(width: s.md),
            Expanded(
              child: SecondaryButton(
                labelKey: AppStrings.resultShare,
                onPressed: controller.share,
              ),
            ),
          ],
        ),
        if (controller.canCorrectKeeper) ...<Widget>[
          SizedBox(height: s.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: controller.openKeeperSheet,
              child: Text(
                AppStrings.resultWrongKeeper.tr,
                style: context.textStyles.labelLg.copyWith(color: p.primary),
              ),
            ),
          ),
        ],
        SizedBox(height: s.md),
        DisclosureLine(onReport: controller.report),
      ],
    );
  }
}
