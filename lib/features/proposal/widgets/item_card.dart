import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../services/processing/processing_api.dart';
import '../model/belonging_label.dart';

/// Object chip for an ambiguous belonging in the Distractions group
/// (Phase A, design X2 construction / X10): mirrors the person
/// chip — a real crop of the item from the photo, its label, and a
/// Remove/Keep state pill. Default state is Keep (X3); tapping flips
/// it. The thumbnail ring stays neutral — state lives in the card
/// border and the pill, and emerald remains reserved for protected
/// people (X7).
class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    required this.imagePath,
    required this.included,
    required this.onTap,
  });

  final DetectedBelonging item;
  final String imagePath;
  final bool included;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final name = belongingClassLabelKey(item.detectedClass).tr;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(s.radiusLg),
      child: Container(
        width: 104,
        padding: EdgeInsets.symmetric(vertical: s.sm, horizontal: s.xs),
        decoration: BoxDecoration(
          color: included
              ? AppColors.crimson.withAlpha(16)
              : p.surfaceVariant.withAlpha(50),
          borderRadius: BorderRadius.circular(s.radiusLg),
          border: Border.all(
            color: included
                ? AppColors.crimson.withAlpha(120)
                : p.border,
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ItemThumbnail(imagePath: imagePath, box: item.box, size: 44),
            SizedBox(height: s.xs),
            Text(
              name,
              style: context.textStyles.labelMd.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: included
                    ? AppColors.crimson.withAlpha(30)
                    : p.surfaceVariant,
                borderRadius: BorderRadius.circular(s.radiusPill),
              ),
              child: Text(
                included
                    ? AppStrings.proposalItemRemove.tr
                    : AppStrings.proposalItemKeep.tr,
                style: context.textStyles.caption.copyWith(
                  color: included ? AppColors.crimson : p.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A square crop of an item's box from the photo (the object-chip
/// counterpart of PersonThumbnail, without person semantics: no ring
/// badge, no keeper/removal token). Degrades to a neutral icon tile
/// until the crop is decoded or if the box is malformed.
class ItemThumbnail extends StatefulWidget {
  const ItemThumbnail({
    super.key,
    required this.imagePath,
    required this.box,
    this.size = 44.0,
  });

  final String imagePath;
  final List<int> box;
  final double size;

  @override
  State<ItemThumbnail> createState() => _ItemThumbnailState();
}

class _ItemThumbnailState extends State<ItemThumbnail> {
  ui.Image? _decodedImage;
  ImageStream? _imageStream;
  ImageStreamListener? _streamListener;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ItemThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) _loadImage();
  }

  void _loadImage() {
    if (widget.box.length < 4 || widget.imagePath.isEmpty) return;
    final file = File(widget.imagePath);
    if (!file.existsSync()) return;
    final provider = FileImage(file);
    _imageStream?.removeListener(_streamListener!);
    _imageStream = provider.resolve(ImageConfiguration.empty);
    _streamListener = ImageStreamListener((ImageInfo info, bool _) {
      if (mounted) setState(() => _decodedImage = info.image);
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
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: p.surfaceVariant,
        borderRadius: BorderRadius.circular(s.radiusSm),
        border: Border.all(color: p.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(s.radiusSm),
        child: _decodedImage != null && widget.box.length >= 4
            ? CustomPaint(
                painter: _ItemCropPainter(
                  image: _decodedImage!,
                  box: widget.box,
                ),
              )
            : Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: widget.size * 0.5,
                  color: p.textSecondary,
                ),
              ),
      ),
    );
  }
}

/// Paints the item's box region of the photo into the square tile,
/// contain-fit (the whole item stays visible; nothing is cropped
/// away that the user is deciding about).
class _ItemCropPainter extends CustomPainter {
  const _ItemCropPainter({required this.image, required this.box});

  final ui.Image image;
  final List<int> box;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTRB(
      box[0].toDouble(),
      box[1].toDouble(),
      box[2].toDouble(),
      box[3].toDouble(),
    );
    if (src.width <= 0 || src.height <= 0) return;
    final scale = (size.width / src.width) < (size.height / src.height)
        ? size.width / src.width
        : size.height / src.height;
    final dst = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: src.width * scale,
      height: src.height * scale,
    );
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(covariant _ItemCropPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.box != box;
}
