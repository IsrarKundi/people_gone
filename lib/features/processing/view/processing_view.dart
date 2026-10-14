import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/diagnostics/diagnostics_log.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../controller/processing_controller.dart';
import '../widgets/scan_beam_overlay.dart';

/// Processing (S3/S6) — Option 1: "The Living Canvas with Beam Scan"
/// Respects system theme (light mode porcelain / dark mode obsidian).
/// The photo is framed at natural brightness on an elevated canvas with a gentle
/// sweeping scan beam proving active processing. Allows working in the background.
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
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Framed photographic canvas in system theme
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: s.screenPadding,
                      vertical: s.xxl,
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
                          alignment: Alignment.center,
                          children: <Widget>[
                            Image.file(
                              File(controller.photoPath),
                              fit: BoxFit.contain,
                              cacheWidth:
                                  MediaQuery.sizeOf(context).width.toInt(),
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                            // Smooth scanning beam proving active intelligence
                            const Positioned.fill(
                              child: ScanBeamOverlay(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom control and status tray
                Positioned(
                  left: s.screenPadding,
                  right: s.screenPadding,
                  bottom: s.screenPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _progressBlock(context),
                      SizedBox(height: s.md),
                      // Work in background action
                      SizedBox(
                        width: double.infinity,
                        height: s.buttonSecondary,
                        child: OutlinedButton.icon(
                          onPressed: controller.workInBackground,
                          icon: Icon(Icons.arrow_back_rounded, size: s.iconSm),
                          label: Text(AppStrings.processingWorkInBackground.tr),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: p.textPrimary,
                            backgroundColor: p.surface,
                            side: BorderSide(color: p.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(s.radiusPill),
                            ),
                          ),
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

  Widget _progressBlock(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final uploading = controller.stage.value == ProcessingStage.uploading;
    final fraction = controller.uploadFraction.value;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(s.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(s.radiusLg),
        border: Border.all(color: p.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: p.scrim.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LinearProgressIndicator(
            value: uploading ? fraction : null,
            color: p.primary,
            backgroundColor: p.surfaceVariant,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          SizedBox(height: s.md),
          Text(
            uploading
                ? '${AppStrings.processingUploading.tr} '
                      '${(fraction * 100).round()}%'
                : AppStrings.processingFindingRemoving.tr,
            style: context.textStyles.bodyMd.copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: s.xs),
          Text(
            '${AppStrings.processingElapsed.trParams(<String, String>{'time': Formatters.elapsed(controller.elapsed.value)})}'
            ' · ${AppStrings.processingExpectation.tr}',
            style: context.textStyles.caption.copyWith(
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

