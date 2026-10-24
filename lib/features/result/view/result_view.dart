import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/cam_frame.dart';
import '../../../core/widgets/cam_mascot.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../controller/result_controller.dart';
import '../widgets/result_photo_area.dart';
import '../widgets/save_receipt_button.dart';

/// Result (S7) — the cleaned photo full-bleed; judge it (hold-to-compare
/// + slider compare, FR-13), then Save / Share / fix. The saves meter
/// is stated before the Save tap (FR-25); the disclosure line is
/// verbatim §11.2B.
class ResultView extends GetView<ResultController> {
  const ResultView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.sizes;
    return AppScaffold(
      body: Column(
        children: <Widget>[
          // Cam, back in the top-right circle (owner journey): the
          // results-ready drawing in a code-drawn green circle, in
          // its own header row above the photo — never over the
          // photo, never over a button. The result screen itself
          // stays clean. Display only.
          Padding(
            padding: EdgeInsets.only(
              right: s.screenPadding,
              bottom: s.sm,
            ),
            child: Row(
              children: const <Widget>[
                Spacer(),
                // Arrive pulse: one slow happy pulse the moment the
                // result appears, then the calm welcome loop.
                CamMascot(mode: CamMode.resultsReady, arrive: true),
              ],
            ),
          ),
          Expanded(child: ResultPhotoArea(controller: controller)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(s.screenPadding),
            // decoration: BoxDecoration(
            //   color: p.surface,
            //   border: Border(top: BorderSide(color: p.border)),
            // ),
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

  Widget _actionZone(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final savedNow = controller.saved.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Fact 1: People removed count with clean subject indicator
        Row(
          children: <Widget>[
            // Icon(AppIcons.checkCircleFill, size: 18, color: p.overlayKept),
            // SizedBox(width: s.xs),
            Expanded(
              child: Text(
                controller.summaryLine,
                style: context.textStyles.titleMd.copyWith(fontSize: 15),
              ),
            ),
          ],
        ),
        if (controller.reflectionWarning) ...<Widget>[
          SizedBox(height: s.xs),
          Row(
            children: <Widget>[
              Icon(AppIcons.info, size: 16, color: p.textSecondary),
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
        ],
        SizedBox(height: s.xs),
        SizedBox(height: s.sm),
        // Editing action bar (G3.3)
        if (controller.canCorrectKeeper)
          Row(
            children: <Widget>[
              Expanded(
                child: SecondaryButton(
                  labelKey: controller.reflectionWarning
                      ? AppStrings.resultReflectionFix
                      : AppStrings.resultBrushFix,
                  onPressed: controller.reflectionWarning
                      ? controller.openReflectionFix
                      : controller.openTouchUp,
                ),
              ),
              SizedBox(width: s.sm),
              Expanded(
                child: SecondaryButton(
                  labelKey: AppStrings.resultWrongKeeper,
                  onPressed: controller.openKeeperSheet,
                ),
              ),
            ],
          )
        else
          SecondaryButton(
            labelKey: controller.reflectionWarning
                ? AppStrings.resultReflectionFix
                : AppStrings.resultBrushFix,
            onPressed: controller.reflectionWarning
                ? controller.openReflectionFix
                : controller.openTouchUp,
          ),
        SizedBox(height: s.md),
        // Output row at bottom (G3.3)
        LayoutBuilder(
          builder: (rowContext, constraints) {
            final saveButton = SaveReceiptButton(controller: controller);
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
                  Expanded(flex: 4, child: saveButton),
                  SizedBox(width: s.sm),
                  Expanded(flex: 2, child: shareButton),
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
        // SizedBox(height: s.xs),
        // DisclosureLine(onReport: controller.report),
      ],
    );
  }
}
