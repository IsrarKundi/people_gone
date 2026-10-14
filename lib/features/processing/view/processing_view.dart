import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/diagnostics/diagnostics_log.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../controller/processing_controller.dart';
import '../widgets/scan_beam_overlay.dart';

/// Processing (S3/S6) — "The Living Canvas", finished per Review 05
/// Supplement (R1, R4–R6, R8, F1): the layout is a column, not a stack
/// of overlaps — the framed photo flexes in the space above a bottom
/// tray that sits in normal flow (status card, the primary action, its
/// caption, Cancel). Stage copy names only real client states: before
/// the first byte moves the stage is "connecting"; the percentage and
/// bar exist only while bytes actually transfer; the server stage is
/// indeterminate (the beam is the activity signal) with the honest
/// expectation line. No stopwatch (R5).
class ProcessingView extends GetView<ProcessingController> {
  const ProcessingView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return AppScaffold(
      body: Obx(() {
        final error = controller.errorMessage.value;
        if (error != null) {
          return ErrorView(
            messageKey: error,
            onRetry: controller.start,
            onShareDiagnostics: () =>
                Share.share(DiagnosticsLog.instance.export()),
          );
        }
        return Container(
          color: p.background,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                // Framed photographic canvas, flexing in the space
                // above the tray (gallery air, not a terminal void).
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      s.screenPadding,
                      s.xxl,
                      s.screenPadding,
                      s.md,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(s.radiusLg),
                        border: Border.all(color: p.border),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: p.scrim.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(s.radiusLg - 1),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Image.file(
                              File(controller.photoPath),
                              fit: BoxFit.contain,
                              cacheWidth:
                                  MediaQuery.sizeOf(context).width.toInt(),
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                            const Positioned.fill(child: ScanBeamOverlay()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom tray — in flow, anchored to the screen bottom.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    s.screenPadding,
                    0,
                    s.screenPadding,
                    s.screenPadding,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _statusCard(context),
                      SizedBox(height: s.md),
                      PrimaryButton(
                        labelKey: AppStrings.processingWorkInBackground,
                        icon: Icons.arrow_back_rounded,
                        height: 56,
                        borderRadius: 28,
                        onPressed: controller.workInBackground,
                      ),
                      SizedBox(height: s.xs),
                      Text(
                        AppStrings.processingLeaveCaption.tr,
                        style: context.textStyles.caption.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                      SizedBox(height: s.xs),
                      TextButton(
                        onPressed: controller.cancel,
                        child: Text(
                          AppStrings.commonCancel.tr,
                          style: context.textStyles.bodySm.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// Status card: the stage title (a real client state, F1), the real
  /// upload bar ONLY while bytes transfer (R4), and the expectation.
  Widget _statusCard(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final uploading = controller.stage.value == ProcessingStage.uploading;
    final moved = controller.uploadMoved.value;
    final fraction = controller.uploadFraction.value;
    final showBar = uploading && moved;

    final String title;
    if (uploading && !moved) {
      title = AppStrings.processingConnecting.tr;
    } else if (uploading) {
      title =
          '${AppStrings.processingUploading.tr} ${(fraction * 100).round()}%';
    } else {
      title = AppStrings.processingFindingRemoving.tr;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(s.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(s.radiusLg),
        border: Border.all(color: p.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showBar) ...<Widget>[
            LinearProgressIndicator(
              value: fraction,
              color: p.primary,
              backgroundColor: p.surfaceVariant,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            SizedBox(height: s.md),
          ],
          Text(
            title,
            style: context.textStyles.bodyMd.copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: s.xs),
          Text(
            AppStrings.processingExpectation.tr,
            style: context.textStyles.caption.copyWith(
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
