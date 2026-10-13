import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../controller/brush_controller.dart';
import '../widgets/brush_canvas.dart';

/// Brush (S5) — full-screen photo surface in the photoChrome idiom:
/// the sanctioned hint in a pill on the photo, drawing controls in the
/// bottom bar. Apply is disabled-with-visible-state when there is
/// nothing painted, never a dead tap.
class BrushView extends GetView<BrushController> {
  const BrushView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return AppScaffold(
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: s.screenPadding,
              vertical: s.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    AppStrings.brushTitle.tr,
                    style: context.textStyles.titleMd,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _photoArea(context)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(s.screenPadding),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: Obx(() => _bottomBar(context)),
          ),
        ],
      ),
    );
  }

  Widget _photoArea(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return Obx(() {
      final loadError = controller.loadError.value;
      if (loadError != null) {
        return ErrorView(
          messageKey: loadError,
          onRetry: controller.loadImageSize,
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          BrushCanvas(
            imagePath: controller.args.imagePath,
            imageSize: controller.imageSize.value,
            strokes: controller.strokes
                .map((stroke) => List<Offset>.of(stroke))
                .toList(),
            strokeDiameterImagePx: controller.brushDiameterImagePx,
            onStrokeStart: controller.startStroke,
            onStrokePoint: controller.addStrokePoint,
            onStrokeEnd: controller.endStroke,
            onScaleResolved: controller.setFittedScale,
          ),
          Positioned(
            left: s.screenPadding,
            right: s.screenPadding,
            top: s.sm,
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
                decoration: BoxDecoration(
                  color: p.photoChromeBg,
                  borderRadius: BorderRadius.circular(s.radiusPill),
                ),
                child: Text(
                  AppStrings.brushHint.tr,
                  style: context.textStyles.bodySm.copyWith(
                    color: p.photoChromeFg,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (controller.isBusy.value)
            Positioned(
              left: s.screenPadding,
              right: s.screenPadding,
              bottom: s.sm,
              child: Container(
                padding: EdgeInsets.all(s.md),
                decoration: BoxDecoration(
                  color: p.photoChromeBg,
                  borderRadius: BorderRadius.circular(s.radiusLg),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    LinearProgressIndicator(
                      value:
                          controller.uploadFraction.value > 0 &&
                              controller.uploadFraction.value < 1
                          ? controller.uploadFraction.value
                          : null,
                      color: p.primary,
                    ),
                    SizedBox(height: s.sm),
                    Text(
                      AppStrings.brushFixing.tr,
                      style: context.textStyles.bodyMd.copyWith(
                        color: p.photoChromeFg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _bottomBar(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final hasStrokes = controller.hasStrokes;
    final busy = controller.isBusy.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(AppStrings.brushSize.tr, style: context.textStyles.labelMd),
            SizedBox(width: s.sm),
            Expanded(
              child: Slider(
                value: controller.brushSizeDisplay.value,
                min: 8,
                max: 64,
                activeColor: p.primary,
                onChanged: busy ? null : controller.setBrushSize,
              ),
            ),
          ],
        ),
        Row(
          children: <Widget>[
            TextButton.icon(
              onPressed: hasStrokes && !busy ? controller.undoStroke : null,
              icon: Icon(Icons.undo, size: s.iconSm),
              label: Text(AppStrings.brushUndo.tr),
            ),
            TextButton.icon(
              onPressed: hasStrokes && !busy ? controller.clearStrokes : null,
              icon: Icon(Icons.clear, size: s.iconSm),
              label: Text(AppStrings.brushClear.tr),
            ),
            const Spacer(),
            TextButton(
              onPressed: busy ? null : controller.cancel,
              child: Text(AppStrings.commonCancel.tr),
            ),
          ],
        ),
        SizedBox(height: s.sm),
        PrimaryButton(
          labelKey: AppStrings.brushApply,
          isLoading: busy,
          onPressed: controller.canApply ? controller.apply : null,
        ),
      ],
    );
  }
}
