import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/diagnostics/diagnostics_log.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/cam_frame.dart';
import '../../../core/widgets/cam_mascot.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/photo_surface.dart';
import '../../../core/widgets/primary_button.dart';
import '../controller/processing_controller.dart';
import '../widgets/server_working_photo_frame.dart';

/// Processing (S3/S6) — "The Living Canvas", finished per Review 05
/// Supplement (R1, R4–R6, R8, F1): the layout is a column, not a stack
/// of overlaps — the framed photo flexes in the space above a bottom
/// tray that sits in normal flow (status card, the primary action, its
/// caption, Cancel). Stage copy names only real client states: before
/// the first byte moves the stage is "connecting"; the percentage and
/// bar exist only while bytes actually transfer; the server stage is
/// indeterminate (the beam is the activity signal) with the honest
/// expectation line. No stopwatch (R5). The frame hugs the photo's own
/// aspect (Review 06 F1 / D13): user photos are never cropped, and the
/// spare space falls on the canvas outside the frame, never inside it.
class ProcessingView extends GetView<ProcessingController> {
  const ProcessingView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        controller.workInBackground();
      },
      child: AppScaffold(
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
            child: SafeArea(child: _ProcessingContent(controller: controller)),
          );
        }),
      ),
    );
  }
}

class _ProcessingContent extends StatefulWidget {
  const _ProcessingContent({required this.controller});

  final ProcessingController controller;

  @override
  State<_ProcessingContent> createState() => _ProcessingContentState();
}

class _ProcessingContentState extends State<_ProcessingContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: AppMotion.enterCurve,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryController,
            curve: AppMotion.enterCurve,
          ),
        );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final content = Column(
      children: <Widget>[
        // Cam, in the middle of the screen on a clean background.
        // The blurred working photo frame that used to fill this
        // space is commented out below (owner, 2026-10-24) —
        // restore it by swapping this Center back for the
        // _FittedPhotoFrame call. Display only.
        const Expanded(
          child: Center(child: CamMascot(mode: CamMode.processing)),
        ),
        // _FittedPhotoFrame(
        //   photoPath: widget.controller.photoPath,
        //   controller: widget.controller,
        // ),
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
              // Obx(() => _statusCard(context)),
              SizedBox(height: s.md),
              PrimaryButton(
                labelKey: AppStrings.processingWorkInBackground,
                icon: AppIcons.caretLeft,
                height: 48,
                borderRadius: 28,
                onPressed: widget.controller.workInBackground,
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
                onPressed: widget.controller.cancel,
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
    );

    if (disableAnimations) {
      return content;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: content),
    );
  }

  /// Status card: the stage title (a real client state, F1), the real
  /// upload bar ONLY while bytes transfer (R4), and the expectation.
  // ignore: unused_element
  Widget _statusCard(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final uploading =
        widget.controller.stage.value == ProcessingStage.uploading;
    final moved = widget.controller.uploadMoved.value;
    final fraction = widget.controller.uploadFraction.value;
    final showBar = uploading && moved;

    final String title;
    if (uploading && !moved) {
      title = AppStrings.processingConnecting.tr;
    } else if (uploading) {
      title =
          '${AppStrings.processingUploading.tr} ${(fraction * 100).round()}%';
    } else {
      title = widget.controller.workingTitle;
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
          AnimatedSwitcher(
            duration: disableAnimations ? Duration.zero : AppMotion.fast,
            switchInCurve: AppMotion.enterCurve,
            switchOutCurve: AppMotion.exitCurve,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              title,
              key: ValueKey<String>(
                '${widget.controller.stage.value}_${uploading && !moved}',
              ),
              style: context.textStyles.bodyMd.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: s.xs),
          Text(
            AppStrings.processingExpectation.tr,
            style: context.textStyles.caption.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The photo's frame, fitted to the photo's own aspect ratio (resolved
/// The photo's fitted canvas, consistent with Proposal and Result:
/// hugs the photo aspect ratio with no rounded borders or inset snapping.
///
/// Currently commented out of the screen above (owner, 2026-10-24),
/// kept here so the blurred working frame can be restored intact.
// ignore: unused_element
class _FittedPhotoFrame extends StatelessWidget {
  const _FittedPhotoFrame({
    required this.photoPath,
    required this.controller,
  });

  final String photoPath;
  final ProcessingController controller;

  @override
  Widget build(BuildContext context) {
    final file = File(photoPath);
    return PhotoSurface(
      imageProvider: ResizeImage(
        FileImage(file),
        width: MediaQuery.sizeOf(context).width.toInt(),
      ),
      builder: (context, band) {
        if (band.width <= 0 || band.height <= 0) {
          return Image.file(
            file,
            fit: BoxFit.contain,
            cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
        }
        // No mascot over the photo any more: Cam now lives centred
        // and whole in the clean zone below the photo (see
        // _ProcessingContent), per the owner's journey.
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: band.left,
              top: band.top,
              width: band.width,
              height: band.height,
              child: ServerWorkingPhotoFrame(
                imageFile: file,
                isWorking: true,
              ),
            ),
          ],
        );
      },
    );
  }
}
