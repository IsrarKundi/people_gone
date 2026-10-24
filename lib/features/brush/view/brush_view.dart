import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/cam_frame.dart';
import '../../../core/widgets/cam_mascot.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../controller/brush_controller.dart';
import '../widgets/brush_canvas.dart';

/// Brush (S5) — finished per Review 07 (B1–B6): the canvas is the
/// fitted photo itself (a work surface, no frame); the hint is a
/// content-sized chip anchored to the photo's fitted top edge that
/// fades once the first stroke lands (B2/D14); the fixing state lives
/// in the dock (B4) — the primary keeps its spinner + "Fixing…"
/// label, a thin determinate bar runs along the dock's top edge while
/// the fix uploads, and Cancel NEVER disables (D15). The size row
/// carries a footprint dot whose diameter tracks the slider (B3).
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
              vertical: s.xs,
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: AppStrings.commonCancel.tr,
                  icon: Icon(AppIcons.close, color: p.textPrimary),
                  onPressed: controller.cancel,
                ),
                SizedBox(width: s.xs),
                Expanded(
                  child: Text(
                    AppStrings.brushTitle.tr,
                    style: context.textStyles.titleMd,
                  ),
                ),
                // Cam, small header avatar (v2 map): in the header row,
                // never over the canvas or the dock tools. Display only.
                const CamMascot(mode: CamMode.avatarSmall),
              ],
            ),
          ),
          Expanded(child: _photoArea(context)),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: Obx(() => _dock(context)),
          ),
        ],
      ),
    );
  }

  Widget _photoArea(BuildContext context) {
    final s = context.sizes;
    final p = context.palette;
    return Obx(() {
      final loadError = controller.loadError.value;
      if (loadError != null) {
        return ErrorView(
          messageKey: loadError,
          onRetry: controller.loadImageSize,
        );
      }
      final hasStrokes = controller.hasStrokes;
      final busy = controller.isBusy.value;
      final adjustingSize = controller.isAdjustingSize.value;
      final displayDiameter = controller.brushSizeDisplay.value;

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
            hintVisible: !controller.hintDismissed.value,
            suggestedRegion: controller.args.suggestedRegion,
          ),
          // Live brush-size circle preview in centre of photo (G3.4)
          if (adjustingSize)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: displayDiameter,
                  height: displayDiameter,
                  decoration: BoxDecoration(
                    color: p.overlayRemoved.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Floating Undo/Clear pills on the canvas (G3.4)
          if (hasStrokes)
            Positioned(
              left: s.screenPadding,
              bottom: s.sm,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _floatingCanvasButton(
                    context,
                    icon: AppIcons.arrowCounterClockwise,
                    labelKey: AppStrings.brushUndo,
                    onTap: busy ? null : controller.undoStroke,
                  ),
                  SizedBox(width: s.xs),
                  _floatingCanvasButton(
                    context,
                    icon: AppIcons.close,
                    labelKey: AppStrings.brushClear,
                    onTap: busy ? null : controller.clearStrokes,
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }

  Widget _floatingCanvasButton(
    BuildContext context, {
    required IconData icon,
    required String labelKey,
    required VoidCallback? onTap,
  }) {
    final p = context.palette;
    final s = context.sizes;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(s.radiusPill),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
          decoration: BoxDecoration(
            color: p.photoChromeBg,
            borderRadius: BorderRadius.circular(s.radiusPill),
            border: Border.all(color: p.border.withValues(alpha: 0.5)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: p.scrim.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: s.iconSm, color: p.photoChromeFg),
              SizedBox(width: s.xs),
              Text(
                labelKey.tr,
                style: context.textStyles.labelMd.copyWith(
                  color: p.photoChromeFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dock(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final busy = controller.isBusy.value;
    final fraction = controller.uploadFraction.value;
    final uploading = busy && fraction > 0 && fraction < 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Dock top-edge bar: real upload fraction only (B4).
        SizedBox(
          height: 3,
          child: uploading
              ? LinearProgressIndicator(
                  value: fraction,
                  color: p.primary,
                  backgroundColor: p.surfaceVariant,
                  minHeight: 3,
                )
              : null,
        ),
        Padding(
          padding: EdgeInsets.all(s.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    AppStrings.brushSize.tr,
                    style: context.textStyles.labelMd,
                  ),
                  SizedBox(width: s.sm),
                  Expanded(
                    child: Slider(
                      value: controller.brushSizeDisplay.value,
                      min: 8,
                      max: 64,
                      activeColor: p.primary,
                      onChangeStart: (_) =>
                          controller.isAdjustingSize.value = true,
                      onChangeEnd: (_) =>
                          controller.isAdjustingSize.value = false,
                      onChanged: busy ? null : controller.setBrushSize,
                    ),
                  ),
                  SizedBox(width: s.sm),
                  // Footprint preview: the dot IS the brush diameter
                  // at display scale, in a fixed slot so the row
                  // never jitters as the size changes (B3).
                  // Uses transform scale to animate smoothly (Item 16).
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Center(
                      child: AnimatedScale(
                        key: const ValueKey('brush_size_dot_scale'),
                        scale: controller.brushSizeDisplay.value / 64.0,
                        duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                            ? Duration.zero
                            : AppMotion.fast,
                        curve: Curves.easeOutCubic,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: p.overlayRemoved.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  const Spacer(),
                  // The exit never disables (D15) — cancelling a fix
                  // in flight simply drops its result.
                  TextButton(
                    onPressed: controller.cancel,
                    child: Text(AppStrings.commonCancel.tr),
                  ),
                ],
              ),
              SizedBox(height: s.sm),
              PrimaryButton(
                labelKey: AppStrings.brushApply,
                loadingLabelKey: AppStrings.brushFixing,
                isLoading: busy,
                onPressed: controller.canApply ? controller.apply : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
