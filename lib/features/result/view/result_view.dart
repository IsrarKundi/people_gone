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
                // The summary extends only when the job actually
                // included group items (design X16); belongings that
                // travelled with a person are never itemised.
                controller.summaryLine,
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
        // Phase D (X13): a probable reflection of a removed person
        // is stated plainly, with the brush as its one action. It
        // never appears when nobody was removed.
        if (controller.reflectionWarning) ...<Widget>[
          SizedBox(height: s.sm),
          Row(
            children: <Widget>[
              Icon(Icons.info_outline, size: 18, color: p.textSecondary),
              SizedBox(width: s.xs),
              Expanded(
                child: Text(
                  AppStrings.resultReflectionWarning.tr,
                  style: context.textStyles.bodySm.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: s.sm),
          SecondaryButton(
            labelKey: AppStrings.resultReflectionFix,
            onPressed: controller.openReflectionFix,
          ),
        ],
        SizedBox(height: s.md),
        // Dominant action row: Save takes 75%, Share 25%. When both
        // labels cannot fit their slots at the current text scale the
        // row stacks (Save full-width, Share full-width beneath) —
        // Review 04 F7: button words never break (§8 item 19).
        LayoutBuilder(
          builder: (rowContext, constraints) {
            final saveButton = PrimaryButton(
              labelKey: savedNow
                  ? AppStrings.resultSaved
                  : AppStrings.resultSave,
              isLoading: controller.isSaving.value,
              onPressed: savedNow ? null : controller.save,
            );
            final shareButton = SecondaryButton(
              labelKey: AppStrings.resultShare,
              onPressed: controller.share,
            );
            final labelStyle = rowContext.textStyles.labelLg.copyWith(
              fontWeight: FontWeight.w600,
            );
            final scaler = MediaQuery.textScalerOf(rowContext);
            double labelWidth(String key) {
              final painter = TextPainter(
                text: TextSpan(text: key.tr, style: labelStyle),
                textScaler: scaler,
                textDirection: Directionality.of(rowContext),
                maxLines: 1,
              )..layout();
              return painter.width;
            }

            // Horizontal content padding inside the Material buttons
            // (both sides): filled/elevated 24dp, outlined 16dp.
            const savePadding = 48.0;
            const sharePadding = 32.0;
            final saveSlot = (constraints.maxWidth - s.sm) * 3 / 4;
            final shareSlot = (constraints.maxWidth - s.sm) / 4;
            final fits =
                labelWidth(
                          savedNow
                              ? AppStrings.resultSaved
                              : AppStrings.resultSave,
                        ) +
                        savePadding <=
                    saveSlot &&
                labelWidth(AppStrings.resultShare) + sharePadding <= shareSlot;
            if (fits) {
              return Row(
                children: <Widget>[
                  Expanded(flex: 3, child: saveButton),
                  SizedBox(width: s.sm),
                  Expanded(flex: 1, child: shareButton),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                saveButton,
                SizedBox(height: s.sm),
                shareButton,
              ],
            );
          },
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
