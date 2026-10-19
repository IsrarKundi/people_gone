import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/photo_surface.dart';
import '../controller/result_controller.dart';
import 'compare_slider.dart';

class ResultPhotoArea extends StatefulWidget {
  const ResultPhotoArea({super.key, required this.controller});
  final ResultController controller;

  @override
  State<ResultPhotoArea> createState() => _ResultPhotoAreaState();
}

class _ResultPhotoAreaState extends State<ResultPhotoArea>
    with SingleTickerProviderStateMixin {
  AnimationController? _dissolveController;

  @override
  void initState() {
    super.initState();
    if (!widget.controller.nobodyRemoved) {
      // Unbounded: the reveal is driven by the one permitted settle
      // spring (AppMotion.springSettle, audit 2026-10-19) instead of
      // a fixed 450 ms tween.
      _dissolveController = AnimationController(vsync: this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        if (disable) {
          _dissolveController?.value = 1.0;
        } else {
          _dissolveController?.animateWith(
            SpringSimulation(AppMotion.springSettle, 0, 1, 0),
          );
        }
        // Phase D warning line is on this screen: one soft warning
        // tick as it appears (audit 2026-10-19 haptic vocabulary).
        if (widget.controller.reflectionWarning) AppHaptics.warning();
      });
    }
  }

  void _cutDissolve() {
    if (_dissolveController != null && !_dissolveController!.isCompleted) {
      _dissolveController!.stop();
      _dissolveController!.value = 1.0;
    }
  }

  @override
  void dispose() {
    _dissolveController?.dispose();
    super.dispose();
  }

  Widget _chromeButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final p = context.palette;
    final s = context.sizes;
    return Container(
      width: s.giant,
      height: s.giant,
      decoration: BoxDecoration(color: p.photoChromeBg, shape: BoxShape.circle),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: p.photoChromeFg, size: s.iconMd),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: s.giant, height: s.giant),
        onPressed: () {
          _cutDissolve();
          onPressed();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final outcome = widget.controller.outcome;
    if (widget.controller.nobodyRemoved) {
      return Image.file(
        File(outcome.originalPath),
        fit: BoxFit.contain,
        cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return Obx(() {
      final comparing = widget.controller.compareMode.value;
      final holding = widget.controller.showOriginal.value;
      final shownPath = holding && !comparing
          ? outcome.originalPath
          : widget.controller.resultPath.value;
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
                resultPath: widget.controller.resultPath.value,
              )
            else
              GestureDetector(
                onLongPressStart: (_) {
                  _cutDissolve();
                  widget.controller.showOriginal.value = true;
                },
                onLongPressEnd: (_) =>
                    widget.controller.showOriginal.value = false,
                onLongPressCancel: () =>
                    widget.controller.showOriginal.value = false,
                onTapDown: (_) => _cutDissolve(),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.file(
                      File(widget.controller.resultPath.value),
                      fit: BoxFit.contain,
                      cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                    if (_dissolveController != null &&
                        !_dissolveController!.isCompleted)
                      AnimatedBuilder(
                        animation: _dissolveController!,
                        builder: (context, _) {
                          final v = _dissolveController!.value;
                          if (v >= 1.0) return const SizedBox.shrink();
                          final fraction = (1.0 - v).clamp(0.0, 1.0);
                          return ClipRect(
                            clipper: FractionClip(fraction),
                            child: Opacity(
                              opacity: fraction,
                              child: Image.file(
                                File(outcome.originalPath),
                                fit: BoxFit.contain,
                                cacheWidth: MediaQuery.sizeOf(
                                  context,
                                ).width.toInt(),
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          );
                        },
                      )
                    else if (holding)
                      Image.file(
                        File(outcome.originalPath),
                        fit: BoxFit.contain,
                        cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            // Chrome pins to the PHOTO band's top corners
            Positioned(
              left: band.left + s.sm,
              top: band.top + s.sm,
              width: (band.width - s.sm * 2).clamp(0.0, double.infinity),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _chromeButton(
                    context,
                    icon: AppIcons.close,
                    tooltip: AppStrings.commonClose.tr,
                    onPressed: widget.controller.goHome,
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
                  else if (!comparing)
                    _chromeButton(
                      context,
                      icon: AppIcons.arrowsLeftRight,
                      tooltip: AppStrings.compareAction.tr,
                      onPressed: widget.controller.toggleCompare,
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
