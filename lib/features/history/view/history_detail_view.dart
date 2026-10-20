import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/photo_surface.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../result/widgets/compare_slider.dart';
import '../controller/history_detail_controller.dart';

/// A saved clean at full quality, with before/after comparison (when the
/// original photo is present), saved date, Share, and Delete.
class HistoryDetailView extends GetView<HistoryDetailController> {
  const HistoryDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final entry = controller.entry;
    return AppScaffold(
      titleKey: AppStrings.historyTitle,
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
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    Formatters.date(entry.savedAt),
                    style: context.textStyles.bodyMd.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                  SizedBox(height: s.md),
                  PrimaryButton(
                    labelKey: AppStrings.resultSave,
                    // icon: AppIcons.checkFill,
                    onPressed: controller.saveToGallery,
                  ),
                  SizedBox(height: s.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SecondaryButton(
                          labelKey: AppStrings.resultShare,
                          onPressed: controller.share,
                        ),
                      ),
                      SizedBox(width: s.sm),
                      Expanded(
                        child: SizedBox(
                          height: s.buttonSecondary,
                          child: OutlinedButton.icon(
                            onPressed: controller.delete,
                            icon: Icon(
                              AppIcons.trash,
                              size: s.iconSm,
                              color: p.error,
                            ),
                            label: Text(
                              AppStrings.commonDelete.tr,
                              style: context.textStyles.labelLg.copyWith(
                                color: p.error,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: p.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(s.radiusMd),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoArea(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final entry = controller.entry;

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final heroTag = disableAnimations
        ? 'disabled_${entry.id}'
        : 'history_photo_${entry.id}';

    Widget wrapHero(Widget child) {
      return Hero(
        tag: heroTag,
        flightShuttleBuilder:
            (
              flightContext,
              animation,
              flightDirection,
              fromHeroContext,
              toHeroContext,
            ) {
              return Image.file(
                File(entry.localPath),
                fit: BoxFit.contain,
                cacheWidth: MediaQuery.sizeOf(flightContext).width.toInt(),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              );
            },
        child: child,
      );
    }

    if (!controller.hasOriginal) {
      return wrapHero(
        Image.file(
          File(entry.localPath),
          fit: BoxFit.contain,
          cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    }

    return Obx(() {
      final comparing = controller.compareMode.value;
      final holding = controller.showOriginal.value;
      final shownPath = holding && !comparing
          ? entry.originalPath!
          : entry.localPath;

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
                originalPath: entry.originalPath!,
                resultPath: entry.localPath,
              )
            else
              GestureDetector(
                onLongPressStart: (_) => controller.showOriginal.value = true,
                onLongPressEnd: (_) => controller.showOriginal.value = false,
                onLongPressCancel: () => controller.showOriginal.value = false,
                child: wrapHero(
                  Image.file(
                    File(shownPath),
                    fit: BoxFit.contain,
                    cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Positioned(
              right: band.right - band.width + s.sm,
              top: band.top + s.sm,
              child: Container(
                width: s.giant,
                height: s.giant,
                decoration: BoxDecoration(
                  color: p.photoChromeBg,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: comparing
                      ? AppStrings.commonClose.tr
                      : AppStrings.compareAction.tr,
                  icon: Icon(
                    comparing ? AppIcons.close : AppIcons.arrowsLeftRight,
                    color: p.photoChromeFg,
                    size: s.iconMd,
                  ),
                  onPressed: controller.toggleCompare,
                ),
              ),
            ),
            if (holding && !comparing)
              Positioned(
                left: band.left + s.sm,
                top: band.top + s.sm,
                child: Container(
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
                ),
              ),
          ],
        ),
      );
    });
  }
}
