import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/storage/local_store.dart';

/// Featured card for the most recently cleaned photo on Home (Option A).
/// Reads the photo's true aspect ratio from the image file at render time
/// without any external aspect metadata store, avoiding head/face cropping.
class FeaturedCleanCard extends StatefulWidget {
  const FeaturedCleanCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  State<FeaturedCleanCard> createState() => _FeaturedCleanCardState();
}

class _FeaturedCleanCardState extends State<FeaturedCleanCard> {
  double _aspectRatio = 4 / 3;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(FeaturedCleanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.localPath != widget.entry.localPath) {
      _cleanupListener();
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _cleanupListener();
    super.dispose();
  }

  void _cleanupListener() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
      _imageStream = null;
      _imageListener = null;
    }
  }

  void _resolveAspectRatio() {
    final file = File(widget.entry.localPath);
    if (!file.existsSync()) return;

    _imageStream = FileImage(file).resolve(const ImageConfiguration());
    _imageListener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final w = info.image.width;
      final h = info.image.height;
      if (w > 0 && h > 0) {
        setState(() {
          _aspectRatio = (w / h).clamp(0.7, 1.8);
        });
      }
    }, onError: (_, _) {});
    _imageStream!.addListener(_imageListener!);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final dateLabel = Formatters.date(widget.entry.savedAt);

    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Size the photo at its true aspect inside whatever
              // space Home's hero slot offers (width- or height-bound,
              // never cropped): a portrait photo grows tall, a
              // landscape one stays wide with gallery air around it.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    final maxH = constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : maxW / _aspectRatio;
                    var w = maxW;
                    var h = w / _aspectRatio;
                    if (h > maxH) {
                      h = maxH;
                      w = h * _aspectRatio;
                    }
                    return Center(
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Image.file(
                              File(widget.entry.localPath),
                              fit: BoxFit.cover,
                              cacheWidth: MediaQuery.sizeOf(
                                context,
                              ).width.toInt(),
                              errorBuilder: (_, _, _) => Container(
                                color: p.surfaceVariant,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: p.border,
                                ),
                              ),
                            ),
                            Positioned(
                              top: s.sm,
                              right: s.sm,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: s.sm,
                                  vertical: s.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.70),
                                  borderRadius: BorderRadius.circular(
                                    s.radiusSm,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 12,
                                      color: p.overlayKept,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Cleaned',
                                      style: context.textStyles.labelMd
                                          .copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: s.md,
                  vertical: s.sm + 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      dateLabel,
                      style: context.textStyles.bodySm.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        Text(
                          'Tap to compare',
                          style: context.textStyles.caption.copyWith(
                            color: p.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: p.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
