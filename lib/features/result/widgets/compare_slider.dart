import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_motion.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/photo_surface.dart';

/// Before/after slider compare (FR-13, Design Direction §4 S7): the
/// original on the left of the divider, the result on the right. Both
/// images share identical contain geometry (output dimensions always
/// equal input dimensions), so the divider aligns pixel-for-pixel.
/// The handle is a 48dp target and TalkBack-adjustable — the slider is
/// the non-gesture accessibility path for comparing.
///
/// StatefulWidget only because divider position is local gesture state.
class CompareSlider extends StatefulWidget {
  const CompareSlider({
    super.key,
    required this.originalPath,
    required this.resultPath,
  });

  final String originalPath;
  final String resultPath;

  /// Session flag: teaching nudge runs at most once per session.
  static bool hasRunCompareNudge = false;

  @override
  State<CompareSlider> createState() => _CompareSliderState();
}

class _CompareSliderState extends State<CompareSlider>
    with SingleTickerProviderStateMixin {
  double _fraction = 0.5;
  AnimationController? _nudgeController;

  @override
  void initState() {
    super.initState();
    if (!CompareSlider.hasRunCompareNudge) {
      CompareSlider.hasRunCompareNudge = true;
      _nudgeController = AnimationController(
        vsync: this,
        duration: AppMotion.compareNudge,
      );
      final animation = TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0.5, end: 0.58)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 50,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0.58, end: 0.5)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 50,
        ),
      ]).animate(_nudgeController!);

      _nudgeController!.addListener(() {
        if (mounted) {
          setState(() => _fraction = animation.value);
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final disable =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        if (disable) {
          _cancelNudge();
        } else {
          _nudgeController?.forward();
        }
      });
    }
  }

  void _cancelNudge() {
    if (_nudgeController?.isAnimating ?? false) {
      _nudgeController?.stop();
    }
  }

  @override
  void dispose() {
    _nudgeController?.dispose();
    super.dispose();
  }

  void _setFromX(double x, double width) {
    if (width <= 0) return;
    setState(() => _fraction = (x / width).clamp(0.0, 1.0));
  }

  void _nudge(double delta) {
    setState(() => _fraction = (_fraction + delta).clamp(0.0, 1.0));
  }

  Widget _image(BuildContext context, String path) {
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  Widget _label(BuildContext context, String key) {
    final p = context.palette;
    final s = context.sizes;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
      decoration: BoxDecoration(
        color: p.photoChromeBg,
        borderRadius: BorderRadius.circular(s.radiusPill),
      ),
      child: Text(
        key.tr,
        style: context.textStyles.labelMd.copyWith(color: p.photoChromeFg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return PhotoSurface(
      imageProvider: ResizeImage(
        FileImage(File(widget.resultPath)),
        width: MediaQuery.sizeOf(context).width.toInt(),
      ),
      builder: (context, band) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final dividerX = _fraction * width;
          // Before/After pills sit at the photo band's top corners
          // BELOW the chrome row (48dp + gap) — labels never overlay
          // the close/compare controls (Review 02 F7/A7).
          final pillsTop = band.top + s.sm + s.giant + s.sm;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _cancelNudge(),
            onHorizontalDragUpdate: (d) => _setFromX(d.localPosition.dx, width),
            onTapDown: (d) => _setFromX(d.localPosition.dx, width),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _image(context, widget.resultPath),
                ClipRect(
                  clipper: _FractionClip(_fraction),
                  child: _image(context, widget.originalPath),
                ),
                Positioned(
                  left: dividerX - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: p.photoChromeFg),
                ),
                Positioned(
                  left: band.left + s.sm,
                  top: pillsTop,
                  child: _label(context, AppStrings.resultBefore),
                ),
                Positioned(
                  right: width - band.right + s.sm,
                  top: pillsTop,
                  child: _label(context, AppStrings.resultAfter),
                ),
                Positioned(
                  left: dividerX - s.giant / 2,
                  top: height / 2 - s.giant / 2,
                  child: Semantics(
                    value: '${(_fraction * 100).round()}%',
                    increasedValue: '${((_fraction + 0.1) * 100).round()}%',
                    decreasedValue: '${((_fraction - 0.1) * 100).round()}%',
                    onIncrease: () => _nudge(0.1),
                    onDecrease: () => _nudge(-0.1),
                    child: Container(
                      width: s.giant,
                      height: s.giant,
                      decoration: BoxDecoration(
                        color: p.photoChromeBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.compare_arrows, color: p.photoChromeFg),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FractionClip extends CustomClipper<Rect> {
  const _FractionClip(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_FractionClip oldClipper) =>
      oldClipper.fraction != fraction;
}
