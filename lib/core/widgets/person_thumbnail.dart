import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_motion.dart';
import '../theme/theme_ext.dart';

/// PersonThumbnail: renders a visual face/body crop from the local photo
/// using the detected bounding box [box] ([x1, y1, x2, y2]).
///
/// If [isKeeper] is true, renders with an emerald keeper ring and check badge;
/// if false, renders with a crimson removal ring and clear badge.
/// Degrades cleanly to an icon avatar if the crop is not yet ready or box is empty.
class PersonThumbnail extends StatefulWidget {
  const PersonThumbnail({
    super.key,
    required this.imagePath,
    required this.box,
    required this.isKeeper,
    this.size = 56.0,
    this.label,
  });

  final String imagePath;
  final List<int> box;
  final bool isKeeper;
  final double size;
  final String? label;

  @override
  State<PersonThumbnail> createState() => _PersonThumbnailState();
}

class _PersonThumbnailState extends State<PersonThumbnail> {
  ui.Image? _decodedImage;
  ImageStream? _imageStream;
  ImageStreamListener? _streamListener;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(PersonThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _loadImage();
    }
  }

  void _loadImage() {
    if (widget.box.length < 4 || widget.imagePath.isEmpty) return;
    final file = File(widget.imagePath);
    if (!file.existsSync()) return;

    final provider = FileImage(file);
    _imageStream?.removeListener(_streamListener!);
    _imageStream = provider.resolve(ImageConfiguration.empty);
    _streamListener = ImageStreamListener((ImageInfo info, bool _) {
      if (mounted) {
        setState(() {
          _decodedImage = info.image;
        });
      }
    });
    _imageStream!.addListener(_streamListener!);
  }

  @override
  void dispose() {
    if (_imageStream != null && _streamListener != null) {
      _imageStream!.removeListener(_streamListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final ringColor = widget.isKeeper ? AppColors.emerald : AppColors.crimson;

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = disableAnimations ? Duration.zero : AppMotion.fast;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedContainer(
          duration: duration,
          curve: AppMotion.standardCurve,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: 2.5),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: ringColor.withAlpha(50),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              ClipOval(
                child: Container(
                  color: p.surfaceVariant,
                  width: widget.size,
                  height: widget.size,
                  child: _decodedImage != null && widget.box.length >= 4
                      ? CustomPaint(
                          painter: _PersonCropPainter(
                            image: _decodedImage!,
                            box: widget.box,
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.person,
                            size: widget.size * 0.55,
                            color: p.textSecondary,
                          ),
                        ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: AnimatedContainer(
                  duration: duration,
                  curve: AppMotion.standardCurve,
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: ringColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.surface, width: 1.5),
                  ),
                  child: Center(
                    child: Icon(
                      widget.isKeeper ? Icons.check : Icons.close,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.label != null) ...<Widget>[
          SizedBox(height: s.xs),
          Text(
            widget.label!,
            style: context.textStyles.caption.copyWith(
              color: widget.isKeeper ? p.textPrimary : p.textSecondary,
              fontWeight: widget.isKeeper ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

class _PersonCropPainter extends CustomPainter {
  const _PersonCropPainter({required this.image, required this.box});

  final ui.Image image;
  final List<int> box;

  @override
  void paint(Canvas canvas, Size size) {
    if (box.length < 4) return;
    final bx1 = box[0].toDouble();
    final by1 = box[1].toDouble();
    final bx2 = box[2].toDouble();
    final by2 = box[3].toDouble();

    final boxW = math.max(1.0, bx2 - bx1);
    final boxH = math.max(1.0, by2 - by1);

    // People detection bounding boxes span the full person.
    // To make an avatar look great, focus on the head / upper torso.
    final upperH = boxH > 40 ? boxH * 0.55 : boxH;
    final centerX = bx1 + boxW / 2;
    final centerY = by1 + upperH / 2;

    // Form a square crop region around head/upper body
    final cropSize = math.max(boxW * 1.1, upperH * 1.1);
    final half = cropSize / 2;

    final srcLeft = (centerX - half).clamp(0.0, image.width.toDouble());
    final srcTop = (centerY - half).clamp(0.0, image.height.toDouble());
    final srcRight = (centerX + half).clamp(0.0, image.width.toDouble());
    final srcBottom = (centerY + half).clamp(0.0, image.height.toDouble());

    final srcRect = Rect.fromLTRB(srcLeft, srcTop, srcRight, srcBottom);
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(image, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant _PersonCropPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.box != box;
  }
}
