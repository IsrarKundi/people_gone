import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The rect a contain-fit photo actually paints into inside [area]:
/// centred, letterboxed — the "photo band" of Design Direction A3.
/// Pure geometry, unit-tested; [PhotoSurface] resolves it live.
Rect photoBandRect(Size area, Size image) {
  if (area.isEmpty || image.isEmpty) return Offset.zero & area;
  final scale = math.min(area.width / image.width, area.height / image.height);
  final size = Size(image.width * scale, image.height * scale);
  return Rect.fromLTWH(
    (area.width - size.width) / 2,
    (area.height - size.height) / 2,
    size.width,
    size.height,
  );
}

/// Photo geometry for the photo screens (Design Direction §5
/// PhotoSurface, Review 02 A3): resolves the image's intrinsic size
/// and hands the builder the photo band — the rect the contain-fit
/// photo paints into — so on-photo chrome and labels pin to the
/// PHOTO's corners, not the screen's, and any dim can be confined to
/// the band. Until the size resolves (or if it fails), the band is
/// the full area: today's layout, corrected a frame later.
///
/// This is the geometry core of the §5 component; pinch/pan and
/// photo-coordinate mask overlays arrive with S4/S5.
class PhotoSurface extends StatefulWidget {
  const PhotoSurface({
    super.key,
    required this.imageProvider,
    required this.builder,
  });

  final ImageProvider imageProvider;

  /// Builds the surface's content; [band] is in this widget's own
  /// coordinate space.
  final Widget Function(BuildContext context, Rect band) builder;

  @override
  State<PhotoSurface> createState() => _PhotoSurfaceState();
}

class _PhotoSurfaceState extends State<PhotoSurface> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(PhotoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) _resolve();
  }

  void _resolve() {
    final stream = widget.imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    if (stream.key == _stream?.key) return;
    _detach();
    _stream = stream;
    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        if (size != _imageSize) setState(() => _imageSize = size);
      },
      // A broken image keeps the full-area band; the caller's own
      // Image errorBuilder owns the failure surface.
      onError: (_, _) {},
    );
    stream.addListener(_listener!);
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        final band = _imageSize == null
            ? Offset.zero & area
            : photoBandRect(area, _imageSize!);
        return widget.builder(context, band);
      },
    );
  }
}
