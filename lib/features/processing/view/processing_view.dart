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
/// expectation line. No stopwatch (R5). The frame hugs the photo's own
/// aspect (Review 06 F1 / D13): user photos are never cropped, and the
/// spare space falls on the canvas outside the frame, never inside it.
class ProcessingView extends GetView<ProcessingController> {
  const ProcessingView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
            child: _ProcessingContent(controller: controller),
          ),
        );
      }),
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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: AppMotion.enterCurve,
    ));
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
        // Framed photographic canvas: the frame is fitted to
        // the photo's aspect and centred in the space above
        // the tray; the canvas around it is the gallery air.
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              s.screenPadding,
              s.xxl,
              s.screenPadding,
              s.md,
            ),
            child: _FittedPhotoFrame(photoPath: widget.controller.photoPath),
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
              Obx(() => _statusCard(context)),
              SizedBox(height: s.md),
              PrimaryButton(
                labelKey: AppStrings.processingWorkInBackground,
                icon: AppIcons.caretLeft,
                height: 56,
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
      child: SlideTransition(
        position: _slideAnimation,
        child: content,
      ),
    );
  }

  /// Status card: the stage title (a real client state, F1), the real
  /// upload bar ONLY while bytes transfer (R4), and the expectation.
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
                  '${widget.controller.stage.value}_${uploading && !moved}'),
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
/// from the file) and centred in the available area — the frame hugs
/// the photo (D13), so no band of empty surface ever sits inside it.
class _FittedPhotoFrame extends StatefulWidget {
  const _FittedPhotoFrame({required this.photoPath});

  final String photoPath;

  @override
  State<_FittedPhotoFrame> createState() => _FittedPhotoFrameState();
}

class _FittedPhotoFrameState extends State<_FittedPhotoFrame> {
  double _aspectRatio = 4 / 3;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _resolve() {
    final file = File(widget.photoPath);
    if (!file.existsSync()) return;
    _stream = FileImage(file).resolve(const ImageConfiguration());
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final w = info.image.width;
      final h = info.image.height;
      if (w > 0 && h > 0) {
        setState(() => _aspectRatio = (w / h).clamp(0.5, 2.4).toDouble());
      }
    }, onError: (_, _) {});
    _stream!.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return LayoutBuilder(
      builder: (context, constraints) {
        var w = constraints.maxWidth;
        var h = w / _aspectRatio;
        if (h > constraints.maxHeight) {
          h = constraints.maxHeight;
          w = h * _aspectRatio;
        }
        return Center(
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(s.photoRadius),
              border: Border.all(color: p.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(s.photoRadius - 1),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.file(
                    File(widget.photoPath),
                    fit: BoxFit.contain,
                    cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  const Positioned.fill(child: ScanBeamOverlay()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
