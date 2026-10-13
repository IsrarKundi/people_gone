import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../controller/processing_controller.dart';

/// Processing (S3/S6) — no app bar; the picked photo full-bleed under a
/// scrim, a staged-progress block in photoChrome treatment, and one
/// Cancel action (Design Direction §4 S3/S6). Stage labels are the
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
          return ErrorView(messageKey: error, onRetry: controller.start);
        }
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.file(
              File(controller.photoPath),
              fit: BoxFit.contain,
              cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            ColoredBox(color: p.scrim),
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
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LinearProgressIndicator(
            value: uploading ? fraction : null,
            color: p.photoChromeFg,
            backgroundColor: p.surfaceVariant,
            minHeight: 4,
          ),
          SizedBox(height: s.md),
          Text(
            uploading
                ? '${AppStrings.processingUploading.tr} '
                      '${(fraction * 100).round()}%'
                : AppStrings.processingFindingRemoving.tr,
            style: context.textStyles.bodyMd.copyWith(color: p.photoChromeFg),
          ),
          SizedBox(height: s.xs),
          Text(
            '${AppStrings.processingElapsed.trParams(<String, String>{'time': Formatters.elapsed(controller.elapsed.value)})}'
            ' · ${AppStrings.processingExpectation.tr}',
            style: context.textStyles.bodySm.copyWith(color: p.photoChromeFg),
          ),
        ],
      ),
    );
  }
}
