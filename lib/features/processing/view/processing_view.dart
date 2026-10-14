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

/// Processing (S3/S6) — no app bar; the picked photo full-bleed, dimmed
/// on its own band only, a staged-progress block in photoChrome
/// treatment, and one Cancel action (Design Direction §4 S3/S6, A3).
/// Stage labels are the
/// requirements' own words; the only numbers shown are the real upload
/// percentage and the real elapsed time.
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
          color: const Color(0xFF0B0D11), // Unified darkroom studio canvas
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Framed photographic canvas without letterbox mismatch
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: s.screenPadding,
                      vertical: s.xxl,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(s.radiusLg),
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Image.file(
                            File(controller.photoPath),
                            fit: BoxFit.contain,
                            cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                          // Subtle darkroom exposure overlay
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withAlpha(90),
                            ),
                          ),
                        ],
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
                      TextButton(
                        onPressed: controller.cancel,
                        style: TextButton.styleFrom(
                          backgroundColor: p.photoChromeBg,
                          padding: EdgeInsets.symmetric(
                            horizontal: s.xl,
                            vertical: s.sm,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(s.radiusPill),
                          ),
                        ),
                        child: Text(
                          AppStrings.commonCancel.tr,
                          style: context.textStyles.labelLg.copyWith(
                            color: p.photoChromeFg,
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
        color: p.photoChromeBg,
        borderRadius: BorderRadius.circular(s.radiusLg),
        border: Border.all(color: Colors.white.withAlpha(20)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
            backgroundColor: Colors.white.withAlpha(30),
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
              color: p.photoChromeFg,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: s.xs),
          Text(
            '${AppStrings.processingElapsed.trParams(<String, String>{'time': Formatters.elapsed(controller.elapsed.value)})}'
            ' · ${AppStrings.processingExpectation.tr}',
            style: context.textStyles.caption.copyWith(
              color: p.photoChromeFg.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }
}
